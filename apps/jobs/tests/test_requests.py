from decimal import Decimal

import pytest

from apps.notifications.models import Notification
from apps.offers.models import WorkerOffer
from conftest import client_for, data, make_image, request_payload

pytestmark = pytest.mark.django_db
URL = "/api/v1/requests/"


class TestCreateRequest:
    def test_customer_creates_request_and_nearby_workers_notified(self, customer, category, make_worker,
                                                                  django_capture_on_commit_callbacks):
        near = make_worker()
        far = make_worker(lat=Decimal("31.800000"), lng=Decimal("74.344000"))
        with django_capture_on_commit_callbacks(execute=True):
            resp = client_for(customer).post(URL, request_payload(category))
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["status"] == "open"
        assert body["matched_workers_count"] == 1
        assert Notification.objects.filter(user=near.user, type="new_request").count() == 1
        assert not Notification.objects.filter(user=far.user).exists()

    def test_with_images(self, customer, category):
        payload = request_payload(category)
        payload["images"] = [make_image("a.jpg"), make_image("b.png", fmt="PNG")]
        resp = client_for(customer).post(URL, payload, format="multipart")
        assert resp.status_code == 201, resp.json()
        assert len(data(resp)["images"]) == 2

    def test_too_many_images(self, customer, category, settings):
        payload = request_payload(category)
        payload["images"] = [make_image(f"{i}.jpg") for i in range(6)]
        assert client_for(customer).post(URL, payload, format="multipart").status_code == 400

    def test_invalid_image(self, customer, category):
        from django.core.files.uploadedfile import SimpleUploadedFile

        payload = request_payload(category)
        payload["images"] = [SimpleUploadedFile("x.jpg", b"not an image", content_type="image/jpeg")]
        assert client_for(customer).post(URL, payload, format="multipart").status_code == 400

    @pytest.mark.parametrize("field,value", [
        ("latitude", "95"), ("longitude", "-190"), ("title", "ab"), ("description", "short"),
        ("preferred_time", "2000-01-01T10:00:00Z"),
    ])
    def test_validation(self, customer, category, field, value):
        resp = client_for(customer).post(URL, request_payload(category, **{field: value}))
        assert resp.status_code == 400
        assert field in resp.json()["error"]["details"]

    def test_inactive_category(self, customer, category):
        category.is_active = False
        category.save()
        assert client_for(customer).post(URL, request_payload(category)).status_code == 400

    def test_worker_cannot_create(self, worker, category):
        assert client_for(worker.user).post(URL, request_payload(category)).status_code == 403

    def test_anonymous_cannot_create(self, api, category):
        assert api.post(URL, request_payload(category)).status_code == 401


class TestListAndPrivacy:
    def test_customer_sees_only_own(self, make_customer, make_request):
        a, b = make_customer(), make_customer()
        ra = make_request(a)
        make_request(b)
        results = data(client_for(a).get(URL))["results"]
        assert [r["id"] for r in results] == [ra.pk]

    def test_other_customer_gets_404(self, make_customer, make_request):
        a, b = make_customer(), make_customer()
        req = make_request(a)
        assert client_for(b).get(f"{URL}{req.pk}/").status_code == 404

    def test_worker_feed_is_filtered_and_private(self, customer, make_request, make_worker, other_category):
        w = make_worker()
        near = make_request(customer)
        make_request(customer, lat=Decimal("31.900000"))  # ~43 km away
        make_request(customer, cat=other_category)  # wrong category
        results = data(client_for(w.user).get(URL))["results"]
        assert [r["id"] for r in results] == [near.pk]
        item = results[0]
        assert "address" not in item and "latitude" not in item and "customer_phone" not in item
        assert item["customer_name"] == "Ayesha"
        assert item["approx_latitude"] == "31.51"
        assert item["distance_km"] == 0.0

    def test_unverified_worker_sees_nothing(self, customer, make_request, make_worker):
        w = make_worker(verified=False)
        req = make_request(customer)
        assert data(client_for(w.user).get(URL))["results"] == []
        assert client_for(w.user).get(f"{URL}{req.pk}/").status_code == 404

    def test_out_of_radius_worker_cannot_open_detail(self, customer, make_request, make_worker):
        w = make_worker(lat=Decimal("31.900000"))
        req = make_request(customer)
        assert client_for(w.user).get(f"{URL}{req.pk}/").status_code == 404

    def test_worker_offered_scope(self, customer, make_request, make_worker, make_offer):
        w = make_worker()
        req = make_request(customer)
        make_offer(w, req)
        results = data(client_for(w.user).get(URL, {"scope": "offered"}))["results"]
        assert [r["id"] for r in results] == [req.pk]
        assert results[0]["my_offer_id"] is not None

    def test_owner_detail_has_address(self, customer, make_request):
        req = make_request(customer)
        body = data(client_for(customer).get(f"{URL}{req.pk}/"))
        assert body["address"] == req.address

    def test_admin_sees_all(self, admin_user, customer, make_request):
        make_request(customer)
        assert data(client_for(admin_user).get(URL))["count"] == 1


class TestUpdateAndCancel:
    def test_owner_updates_open_request(self, customer, make_request):
        req = make_request(customer)
        resp = client_for(customer).patch(f"{URL}{req.pk}/", {"title": "Two fans broken"})
        assert resp.status_code == 200
        req.refresh_from_db()
        assert req.title == "Two fans broken"

    def test_location_not_editable(self, customer, make_request):
        req = make_request(customer)
        client_for(customer).patch(f"{URL}{req.pk}/", {"latitude": "32.0"})
        req.refresh_from_db()
        assert req.latitude == Decimal("31.510000")

    def test_non_owner_cannot_update(self, make_customer, make_request):
        a, b = make_customer(), make_customer()
        req = make_request(a)
        assert client_for(b).patch(f"{URL}{req.pk}/", {"title": "hijacked"}).status_code == 404

    def test_cancel_closes_pending_offers(self, customer, make_request, make_worker, make_offer):
        w = make_worker()
        req = make_request(customer)
        offer = make_offer(w, req)
        resp = client_for(customer).post(f"{URL}{req.pk}/cancel/", {"reason": "Fixed it myself"})
        assert resp.status_code == 200
        assert data(resp)["status"] == "cancelled"
        offer.refresh_from_db()
        assert offer.status == WorkerOffer.Status.CLOSED
        assert Notification.objects.filter(user=w.user, type="request_cancelled").exists()

    def test_cannot_cancel_booked_request(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = client_for(customer).post(f"{URL}{booking.request_id}/cancel/", {})
        assert resp.status_code == 409

    def test_cannot_edit_booked_request(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(customer).patch(f"{URL}{booking.request_id}/", {"title": "x" * 10}).status_code == 409


class TestRequestNearbyWorkers:
    def test_owner_sees_matching_workers(self, customer, make_request, make_worker):
        w = make_worker()
        make_worker(verified=False)
        req = make_request(customer)
        resp = client_for(customer).get(f"{URL}{req.pk}/nearby-workers/")
        assert [r["id"] for r in data(resp)] == [w.pk]

    def test_worker_cannot_view(self, customer, make_request, worker):
        req = make_request(customer)
        assert client_for(worker.user).get(f"{URL}{req.pk}/nearby-workers/").status_code == 403
