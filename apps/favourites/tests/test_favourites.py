from datetime import datetime, time, timedelta

import pytest
from django.utils import timezone

from apps.favourites.models import FavouriteWorker
from apps.jobs.models import ServiceRequest
from apps.notifications.models import Notification
from apps.offers.services import accept_offer, create_offer
from apps.scheduling.models import TimeOff, WorkingHours
from conftest import client_for, data, request_payload

FAVS = "/api/v1/favourites/"
REQUESTS = "/api/v1/requests/"


def local(day, hh):
    return datetime.combine(day, time(hh), tzinfo=timezone.get_current_timezone())


def next_monday():
    today = timezone.localdate()
    return today + timedelta(days=(0 - today.weekday()) % 7 + 7)


def book_again(customer, category, worker, when=None, **kw):
    when = when or local(next_monday(), 10)
    return client_for(customer).post(
        REQUESTS, request_payload(category, preferred_time=when.isoformat(), worker=worker.pk, **kw), format="json"
    )


@pytest.mark.django_db
class TestFavourites:
    def test_save_list_remove(self, customer, make_worker):
        a, b = make_worker(name="Ali Raza"), make_worker(name="Bilal Ahmed")
        c = client_for(customer)
        assert c.post(FAVS, {"worker": a.pk}, format="json").status_code == 201
        resp = c.post(FAVS, {"worker": b.pk}, format="json")
        assert resp.status_code == 201 and data(resp)["is_favourite"] is True
        # Saving twice is fine.
        assert c.post(FAVS, {"worker": a.pk}, format="json").status_code == 201
        listed = data(c.get(FAVS))
        assert [w["id"] for w in listed] == [b.pk, a.pk]
        assert all(w["is_favourite"] for w in listed)
        assert "phone" not in str(listed) and "cnic" not in str(listed).lower()
        assert c.delete(f"{FAVS}{b.pk}/").status_code == 204
        assert [w["id"] for w in data(c.get(FAVS))] == [a.pk]

    def test_unverified_or_suspended_workers(self, customer, make_worker):
        pending = make_worker(verified=False)
        c = client_for(customer)
        assert c.post(FAVS, {"worker": pending.pk}, format="json").status_code == 400
        w = make_worker()
        c.post(FAVS, {"worker": w.pk}, format="json")
        w.user.is_suspended = True
        w.user.save()
        assert data(c.get(FAVS)) == []  # hidden while suspended

    def test_only_customers(self, worker, make_worker, api):
        assert client_for(worker.user).get(FAVS).status_code == 403
        assert api.get(FAVS).status_code == 401

    def test_each_customer_sees_only_their_own(self, make_customer, make_worker):
        w = make_worker()
        one, two = make_customer(), make_customer()
        client_for(one).post(FAVS, {"worker": w.pk}, format="json")
        assert data(client_for(two).get(FAVS)) == []
        client_for(two).delete(f"{FAVS}{w.pk}/")
        assert FavouriteWorker.objects.filter(customer=one).count() == 1

    def test_worker_profile_flags_favourite(self, customer, worker, api):
        url = f"/api/v1/workers/{worker.pk}/"
        assert data(client_for(customer).get(url))["is_favourite"] is False
        client_for(customer).post(FAVS, {"worker": worker.pk}, format="json")
        assert data(client_for(customer).get(url))["is_favourite"] is True
        assert data(api.get(url))["is_favourite"] is False

    def test_recent_workers(self, customer, make_worker, completed_booking_factory, make_customer):
        a, b = make_worker(name="A"), make_worker(name="B")
        completed_booking_factory(customer, a)
        completed_booking_factory(customer, b)
        completed_booking_factory(make_customer(), make_worker(name="Other"))
        recent = data(client_for(customer).get(f"{FAVS}recent/"))
        assert [w["id"] for w in recent] == [b.pk, a.pk]
        assert recent[0]["last_booked_at"] and recent[0]["is_favourite"] is False


@pytest.mark.django_db
class TestBookAgain:
    def test_only_the_invited_worker_is_alerted_and_sees_it(self, customer, category, make_worker,
                                                             django_capture_on_commit_callbacks):
        chosen, other = make_worker(name="Chosen"), make_worker(name="Other")
        with django_capture_on_commit_callbacks(execute=True):
            resp = book_again(customer, category, chosen)
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["invited_worker"] == {"id": chosen.pk, "full_name": "Chosen"}
        assert body["matched_workers_count"] == 1
        alerted = set(Notification.objects.filter(type=Notification.Type.NEW_REQUEST).values_list("user_id", flat=True))
        assert alerted == {chosen.user_id}
        rid = body["id"]
        feed = data(client_for(chosen.user).get(REQUESTS))["results"]
        assert [r["id"] for r in feed] == [rid] and feed[0]["is_direct"] is True
        assert data(client_for(other.user).get(REQUESTS))["results"] == []
        assert client_for(other.user).get(f"{REQUESTS}{rid}/").status_code == 404

    def test_other_workers_cannot_offer(self, customer, category, make_worker):
        chosen, other = make_worker(), make_worker()
        rid = data(book_again(customer, category, chosen))["id"]
        req = ServiceRequest.objects.get(pk=rid)
        from apps.common.exceptions import BusinessRuleError

        with pytest.raises(BusinessRuleError):
            create_offer(other, req, price=1000, estimated_arrival_minutes=30, message="")
        offer = create_offer(chosen, req, price=1000, estimated_arrival_minutes=30, message="")
        booking = accept_offer(offer, customer)
        assert booking.worker == chosen

    @pytest.mark.parametrize("reason", ["off_hours", "time_off", "busy"])
    def test_refused_when_worker_not_free(self, reason, customer, category, worker, make_customer, make_request):
        day = next_monday()
        if reason == "off_hours":
            WorkingHours.objects.create(worker=worker, weekday=1, start_time=time(9), end_time=time(17))
        elif reason == "time_off":
            TimeOff.objects.create(worker=worker, start_date=day, end_date=day)
        else:
            other = make_customer()
            req = make_request(other, preferred_time=local(day, 10))
            accept_offer(create_offer(worker, req, price=1000, estimated_arrival_minutes=30, message=""), other)
        resp = book_again(customer, category, worker, when=local(day, 11))
        assert resp.status_code == 409
        assert resp.json()["error"]["code"] == f"worker_{reason}"
        assert not ServiceRequest.objects.filter(customer=customer).exists()  # rolled back

    def test_refused_when_worker_cannot_take_it(self, customer, category, other_category, make_worker):
        offline = make_worker(available=False)
        assert book_again(customer, category, offline).json()["error"]["code"] == "worker_unavailable"
        plumber = make_worker(categories=[other_category])
        assert book_again(customer, category, plumber).json()["error"]["code"] == "worker_unavailable"
        far = make_worker(lat="31.9000", lng="74.9000", radius=5)
        assert book_again(customer, category, far).json()["error"]["code"] == "worker_too_far"
        unverified = make_worker(verified=False)
        assert book_again(customer, category, unverified).status_code == 400

    def test_no_emergency_book_again(self, customer, category, worker):
        resp = book_again(customer, category, worker, is_emergency=True)
        assert resp.status_code == 400

    def test_worker_declines_then_others_get_it(self, customer, category, make_worker,
                                                django_capture_on_commit_callbacks):
        chosen, other = make_worker(name="Chosen Worker"), make_worker(name="Other")
        rid = data(book_again(customer, category, chosen))["id"]
        assert client_for(other.user).post(f"{REQUESTS}{rid}/decline/").status_code == 404
        with django_capture_on_commit_callbacks(execute=True):
            assert client_for(chosen.user).post(f"{REQUESTS}{rid}/decline/").status_code == 204
        req = ServiceRequest.objects.get(pk=rid)
        assert req.invited_worker is None and req.is_open
        assert Notification.objects.filter(user=other.user, type=Notification.Type.NEW_REQUEST).exists()
        assert not Notification.objects.filter(user=chosen.user, type=Notification.Type.NEW_REQUEST,
                                               data__request_id=rid).exclude(data__is_direct=True).exists()
        note = Notification.objects.get(user=customer, data__request_id=rid)
        assert "Chosen" in note.title
        # Now everyone can see it, and the decliner cannot decline again.
        assert [r["id"] for r in data(client_for(other.user).get(REQUESTS))["results"]] == [rid]
        assert client_for(chosen.user).post(f"{REQUESTS}{rid}/decline/").status_code == 404

    def test_customer_opens_to_everyone(self, customer, category, make_worker, make_customer):
        chosen, other = make_worker(), make_worker()
        rid = data(book_again(customer, category, chosen))["id"]
        assert client_for(make_customer()).post(f"{REQUESTS}{rid}/open-to-all/").status_code == 404
        resp = client_for(customer).post(f"{REQUESTS}{rid}/open-to-all/")
        assert resp.status_code == 200
        body = data(resp)
        assert body["invited_worker"] is None and body["matched_workers_count"] == 1
        assert client_for(customer).post(f"{REQUESTS}{rid}/open-to-all/").status_code == 409
        assert rid in [r["id"] for r in data(client_for(other.user).get(REQUESTS))["results"]]

    def test_normal_requests_unchanged(self, customer, category, make_worker):
        make_worker()
        body = data(client_for(customer).post(REQUESTS, request_payload(category), format="json"))
        assert body["invited_worker"] is None


@pytest.mark.django_db
class TestWorkerSlots:
    def test_free_and_busy_slots(self, customer, worker, make_customer, make_request):
        day = next_monday()
        WorkingHours.objects.create(worker=worker, weekday=0, start_time=time(8), end_time=time(16))
        other = make_customer()
        accept_offer(create_offer(worker, make_request(other, preferred_time=local(day, 10)), price=1000,
                                  estimated_arrival_minutes=30, message=""), other)
        resp = client_for(customer).get(f"/api/v1/workers/{worker.pk}/slots/", {"date": day.isoformat()})
        assert resp.status_code == 200, resp.json()
        free = {timezone.localtime(datetime.fromisoformat(s["start"])).hour: s["free"] for s in data(resp)}
        assert free == {8: True, 10: False, 12: True, 14: True, 16: False, 18: False}

    def test_offline_worker_has_no_free_slots(self, customer, make_worker):
        w = make_worker(available=False)
        resp = client_for(customer).get(f"/api/v1/workers/{w.pk}/slots/", {"date": next_monday().isoformat()})
        assert not any(s["free"] for s in data(resp))

    def test_validation_and_access(self, customer, worker, make_worker, api):
        url = f"/api/v1/workers/{worker.pk}/slots/"
        assert client_for(customer).get(url).status_code == 400
        assert api.get(url, {"date": next_monday().isoformat()}).status_code == 401
        assert client_for(worker.user).get(url, {"date": next_monday().isoformat()}).status_code == 403
        hidden = make_worker(verified=False)
        assert client_for(customer).get(f"/api/v1/workers/{hidden.pk}/slots/",
                                        {"date": next_monday().isoformat()}).status_code == 404
