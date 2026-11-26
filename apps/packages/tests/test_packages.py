from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking, ServiceRequest
from apps.notifications.models import Notification
from apps.offers.models import WorkerOffer
from apps.packages.models import MAX_PACKAGES, ServicePackage
from apps.scheduling.models import TimeOff
from conftest import LAHORE, client_for, data

MINE = "/api/v1/workers/me/packages/"


def package_payload(category, **kw):
    body = {"category": category.pk, "title": "AC service", "description": "Full indoor and outdoor unit clean.",
            "includes": ["Filter wash", "Gas pressure check"], "price": "2500", "duration_minutes": 90}
    body.update(kw)
    return body


def make_package(worker, category, **kw):
    fields = {"title": "AC service", "price": Decimal("2500"), "duration_minutes": 90, "includes": ["Filter wash"]}
    fields.update(kw)
    return ServicePackage.objects.create(worker=worker, category=category, **fields)


def book_payload(hours=3, **kw):
    when = (timezone.now() + timedelta(hours=hours)).replace(minute=0, second=0, microsecond=0)
    body = {"preferred_time": when.isoformat(), "latitude": str(LAHORE[0]), "longitude": str(LAHORE[1]),
            "address": "House 12, Street 4, Gulberg III, Lahore", "area": "Gulberg III"}
    body.update(kw)
    return body


def book(customer, package, **kw):
    return client_for(customer).post(f"/api/v1/packages/{package.pk}/book/", book_payload(**kw))


@pytest.mark.django_db
class TestManage:
    def test_worker_adds_lists_edits_and_deletes(self, worker, category):
        c = client_for(worker.user)
        resp = c.post(MINE, package_payload(category, includes=["Filter wash", "  ", "Gas check"]))
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["includes"] == ["Filter wash", "Gas check"] and body["price"] == "2500.00"
        assert body["is_active"] is True and body["times_booked"] == 0
        pk = body["id"]
        assert [p["id"] for p in data(c.get(MINE))] == [pk]
        resp = c.patch(f"{MINE}{pk}/", {"price": "2800", "is_active": False})
        assert resp.status_code == 200 and data(resp)["price"] == "2800.00" and data(resp)["is_active"] is False
        assert c.delete(f"{MINE}{pk}/").status_code == 204
        assert not ServicePackage.objects.exists()

    def test_only_for_services_the_worker_offers(self, worker, other_category):
        resp = client_for(worker.user).post(MINE, package_payload(other_category))
        assert resp.status_code == 400 and resp.json()["error"]["code"] == "service_not_offered"

    def test_price_and_duration_limits(self, worker, category):
        c = client_for(worker.user)
        assert c.post(MINE, package_payload(category, price="10")).status_code == 400
        assert c.post(MINE, package_payload(category, duration_minutes=10)).status_code == 400
        assert c.post(MINE, package_payload(category, includes=["x"] * 9)).status_code == 400
        assert c.post(MINE, package_payload(category, title=" a ")).status_code == 400
        assert not ServicePackage.objects.exists()

    def test_at_most_ten(self, worker, category):
        for i in range(MAX_PACKAGES):
            make_package(worker, category, title=f"Package {i}")
        resp = client_for(worker.user).post(MINE, package_payload(category))
        assert resp.status_code == 400 and resp.json()["error"]["code"] == "too_many_packages"

    def test_workers_only_touch_their_own(self, worker, make_worker, category, customer):
        other = make_worker()
        theirs = make_package(other, category)
        c = client_for(worker.user)
        assert c.patch(f"{MINE}{theirs.pk}/", {"price": "100"}).status_code == 404
        assert c.delete(f"{MINE}{theirs.pk}/").status_code == 404
        assert client_for(customer).get(MINE).status_code == 403
        assert client_for(customer).post(MINE, package_payload(category)).status_code == 403


@pytest.mark.django_db
class TestBrowse:
    def test_public_lists_hide_paused_hidden_and_unverified(self, api, worker, make_worker, category):
        shown = make_package(worker, category)
        make_package(worker, category, title="Paused", is_active=False)
        make_package(worker, category, title="Hidden", is_hidden=True)
        make_package(make_worker(verified=False), category, title="Unverified")
        assert [p["id"] for p in data(api.get(f"/api/v1/workers/{worker.pk}/packages/"))] == [shown.pk]
        listed = data(api.get("/api/v1/packages/"))["results"]
        assert [p["id"] for p in listed] == [shown.pk]
        card = listed[0]
        assert card["worker"]["full_name"] == worker.user.full_name
        assert "phone" not in str(card) and "cnic" not in str(card).lower()
        assert api.get(f"/api/v1/packages/{shown.pk}/").status_code == 200

    def test_dropped_service_hides_its_packages(self, api, worker, category):
        pkg = make_package(worker, category)
        worker.services.update(is_active=False)
        assert data(api.get("/api/v1/packages/"))["count"] == 0
        assert api.get(f"/api/v1/packages/{pkg.pk}/").status_code == 404

    def test_filters_by_category_price_and_area(self, api, make_worker, category, other_category):
        near = make_worker(categories=[category, other_category])
        far = make_worker(lat=Decimal("31.900000"), lng=Decimal("74.900000"), radius=Decimal("5"))
        a = make_package(near, category, price=Decimal("1500"))
        b = make_package(near, other_category, title="Tap fix", price=Decimal("800"))
        c = make_package(far, category, price=Decimal("1000"))

        def ids(**params):
            return {p["id"] for p in data(api.get("/api/v1/packages/", params))["results"]}

        assert ids(category=category.pk) == {a.pk, c.pk}
        assert ids(max_price="1000") == {b.pk, c.pk}
        assert ids(latitude=str(LAHORE[0]), longitude=str(LAHORE[1])) == {a.pk, b.pk}
        assert ids(category="abc") == set()


@pytest.mark.django_db
class TestBook:
    def test_books_straight_away_at_the_fixed_price(self, customer, worker, category,
                                                    django_capture_on_commit_callbacks):
        pkg = make_package(worker, category, description="Indoor and outdoor clean.")
        with django_capture_on_commit_callbacks(execute=True):
            resp = book(customer, pkg, notes="Gate code 1234")
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["status"] == "confirmed" and body["agreed_price"] == "2500.00"
        assert body["package_id"] == pkg.pk and body["duration_minutes"] == 90 and body["title"] == "AC service"
        booking = Booking.objects.get()
        req = booking.request
        assert req.status == ServiceRequest.Status.BOOKED and req.invited_worker == worker and req.package == pkg
        assert "Filter wash" in req.description and "Gate code 1234" in req.description
        assert booking.offer.status == WorkerOffer.Status.ACCEPTED
        pkg.refresh_from_db()
        assert pkg.times_booked == 1
        note = Notification.objects.get(user=worker.user)
        assert note.title == "New package booking" and "AC service" in note.body
        assert note.data["booking_id"] == booking.pk
        # The OTP is never in the response.
        assert "otp" not in str(body).lower().replace("completed_via", "")

    def test_uses_a_saved_address(self, customer, worker, category):
        from apps.addresses.models import SavedAddress

        home = SavedAddress.objects.create(user=customer, label="home", address="House 1, Gulberg, Lahore",
                                           area="Gulberg", latitude=LAHORE[0], longitude=LAHORE[1])
        pkg = make_package(worker, category)
        body = book_payload(saved_address=home.pk)
        for k in ("latitude", "longitude", "address", "area"):
            body.pop(k)
        resp = client_for(customer).post(f"/api/v1/packages/{pkg.pk}/book/", body)
        assert resp.status_code == 201, resp.json()
        assert Booking.objects.get().request.area == "Gulberg"

    def test_someone_elses_saved_address_is_refused(self, customer, make_customer, worker, category):
        from apps.addresses.models import SavedAddress

        theirs = SavedAddress.objects.create(user=make_customer(), label="home", address="House 9, DHA, Lahore",
                                             latitude=LAHORE[0], longitude=LAHORE[1])
        pkg = make_package(worker, category)
        body = book_payload(saved_address=theirs.pk)
        for k in ("latitude", "longitude", "address"):
            body.pop(k)
        assert client_for(customer).post(f"/api/v1/packages/{pkg.pk}/book/", body).status_code == 400

    def test_busy_worker_cannot_be_double_booked(self, customer, make_customer, worker, category):
        pkg = make_package(worker, category)
        assert book(customer, pkg, hours=5).status_code == 201
        resp = book(make_customer(), pkg, hours=5)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "worker_busy"
        assert Booking.objects.count() == 1 and ServiceRequest.objects.count() == 1  # nothing left behind

    def test_same_customer_same_time_is_a_duplicate(self, customer, worker, category):
        pkg = make_package(worker, category)
        assert book(customer, pkg, hours=7).status_code == 201
        resp = book(customer, pkg, hours=7)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "duplicate_booking"

    def test_time_off_and_far_addresses_are_refused(self, customer, worker, category):
        pkg = make_package(worker, category)
        resp = book(customer, pkg, latitude="31.900000", longitude="74.900000")
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "worker_too_far"
        day = timezone.localdate() + timedelta(days=3)
        TimeOff.objects.create(worker=worker, start_date=day, end_date=day)
        from datetime import datetime, time

        start = datetime.combine(day, time(11), tzinfo=timezone.get_current_timezone())
        resp = book(customer, pkg, preferred_time=start.isoformat())
        assert resp.status_code == 409
        assert not ServiceRequest.objects.exists()

    def test_paused_hidden_or_unavailable_packages_cannot_be_booked(self, customer, worker, category):
        paused = make_package(worker, category, is_active=False)
        hidden = make_package(worker, category, is_hidden=True)
        for pkg in (paused, hidden):
            resp = book(customer, pkg)
            assert resp.status_code == 409 and resp.json()["error"]["code"] == "package_unavailable"
        live = make_package(worker, category)
        worker.is_available = False
        worker.save()
        assert book(customer, live).status_code == 409
        assert not Booking.objects.exists()

    def test_validation_and_roles(self, customer, worker, category):
        pkg = make_package(worker, category)
        assert book(customer, pkg, hours=-2).status_code == 400
        assert book(customer, pkg, hours=24 * 61).status_code == 400
        assert client_for(customer).post(f"/api/v1/packages/{pkg.pk}/book/", {}).status_code == 400
        assert book(worker.user, pkg).status_code == 403
        assert client_for(customer).post("/api/v1/packages/99999/book/", book_payload()).status_code == 404

    def test_package_booking_works_like_any_booking(self, customer, worker, category):
        from apps.jobs.services import cancel_booking

        pkg = make_package(worker, category)
        assert book(customer, pkg).status_code == 201
        booking = Booking.objects.get()
        resp = client_for(worker.user).get(f"/api/v1/bookings/{booking.pk}/")
        assert resp.status_code == 200 and data(resp)["package_id"] == pkg.pk
        cancel_booking(booking, customer, "Plans changed")
        assert ServiceRequest.objects.get().status == ServiceRequest.Status.CANCELLED
        # Deleting the package keeps the booking.
        pkg.delete()
        booking.refresh_from_db()
        assert booking.request.package is None and booking.agreed_price == Decimal("2500.00")


@pytest.mark.django_db
class TestAdmin:
    def test_admin_hides_and_shows_with_audit(self, admin_user, worker, category, api):
        pkg = make_package(worker, category)
        c = client_for(admin_user)
        assert data(c.get("/api/v1/admin/packages/"))["count"] == 1
        resp = c.post(f"/api/v1/admin/packages/{pkg.pk}/hide/", {"reason": "Misleading price"})
        assert resp.status_code == 200 and data(resp)["is_hidden"] is True
        assert data(api.get("/api/v1/packages/"))["count"] == 0
        assert Notification.objects.filter(user=worker.user, title="Package hidden").exists()
        mine = data(client_for(worker.user).get(MINE))[0]
        assert mine["is_hidden"] is True and mine["hidden_reason"] == "Misleading price"
        assert c.post(f"/api/v1/admin/packages/{pkg.pk}/unhide/").status_code == 200
        assert data(api.get("/api/v1/packages/"))["count"] == 1
        assert AuditLog.objects.filter(action=AuditLog.Action.PACKAGE_MODERATED).count() == 2

    def test_only_admins(self, worker, category):
        pkg = make_package(worker, category)
        c = client_for(worker.user)
        assert c.get("/api/v1/admin/packages/").status_code == 403
        assert c.post(f"/api/v1/admin/packages/{pkg.pk}/hide/", {"reason": "nope"}).status_code == 403
