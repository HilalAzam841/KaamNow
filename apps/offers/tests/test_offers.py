from decimal import Decimal

import pytest

from apps.jobs.models import Booking, ServiceRequest
from apps.notifications.models import Notification
from apps.offers.models import Negotiation, WorkerOffer
from conftest import client_for, data

pytestmark = pytest.mark.django_db


def offers_url(req):
    return f"/api/v1/requests/{req.pk}/offers/"


OFFER = {"price": "1000", "estimated_arrival_minutes": 30, "message": "I have all tools"}


class TestSubmitOffer:
    def test_eligible_worker_submits_offer(self, customer, worker, make_request):
        req = make_request(customer)
        resp = client_for(worker.user).post(offers_url(req), OFFER)
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["current_price"] == "1000.00"
        assert body["awaiting"] == "customer"
        assert body["negotiations"][0]["action"] == "offer"
        assert Notification.objects.filter(user=customer, type="new_offer").exists()

    def test_duplicate_offer_rejected(self, customer, worker, make_request):
        req = make_request(customer)
        client = client_for(worker.user)
        assert client.post(offers_url(req), OFFER).status_code == 201
        assert client.post(offers_url(req), OFFER).status_code == 409
        assert WorkerOffer.objects.filter(request=req).count() == 1

    def test_ineligible_workers(self, customer, make_request, make_worker, other_category):
        req = make_request(customer)
        for w in (make_worker(verified=False), make_worker(available=False),
                  make_worker(categories=[other_category]), make_worker(lat=Decimal("31.900000"))):
            assert client_for(w.user).post(offers_url(req), OFFER).status_code == 403

    def test_customer_cannot_offer(self, customer, make_request):
        req = make_request(customer)
        assert client_for(customer).post(offers_url(req), OFFER).status_code == 403

    @pytest.mark.parametrize("price", ["10", "5000000"])
    def test_price_bounds(self, customer, worker, make_request, price):
        req = make_request(customer)
        assert client_for(worker.user).post(offers_url(req), {**OFFER, "price": price}).status_code == 400

    def test_cannot_offer_on_closed_request(self, customer, worker, make_worker, make_booking, make_offer):
        booking = make_booking(customer, worker)
        other = make_worker()
        resp = client_for(other.user).post(offers_url(booking.request), OFFER)
        assert resp.status_code == 409


class TestCompareOffers:
    def test_customer_compares_and_sorts(self, customer, make_request, make_worker, make_offer):
        req = make_request(customer)
        w1 = make_worker(name="Cheap", experience=2)
        w2 = make_worker(name="Pricey", experience=12)
        w2.average_rating = Decimal("4.90")
        w2.save()
        make_offer(w1, req, "800")
        make_offer(w2, req, "1500")
        client = client_for(customer)
        by_price = data(client.get(offers_url(req)))["results"]
        assert [o["current_price"] for o in by_price] == ["800.00", "1500.00"]
        card = by_price[0]["worker"]
        assert {"average_rating", "completed_jobs_count", "experience_years", "is_verified"} <= set(card)
        assert "phone" not in card
        by_rating = data(client.get(offers_url(req), {"ordering": "rating"}))["results"]
        assert by_rating[0]["worker"]["full_name"] == "Pricey"
        by_exp = data(client.get(offers_url(req), {"ordering": "experience"}))["results"]
        assert by_exp[0]["worker"]["experience_years"] == 12

    def test_worker_sees_only_own_offer(self, customer, make_request, make_worker, make_offer):
        req = make_request(customer)
        w1, w2 = make_worker(), make_worker()
        make_offer(w1, req, "800")
        make_offer(w2, req, "900")
        results = data(client_for(w1.user).get(offers_url(req)))["results"]
        assert len(results) == 1 and results[0]["worker"]["id"] == w1.pk

    def test_outsider_cannot_list(self, make_customer, make_request):
        req = make_request(make_customer())
        assert client_for(make_customer()).get(offers_url(req)).status_code == 404


class TestNegotiation:
    def test_spec_example_1000_800_900_confirm(self, customer, worker, make_request):
        """Worker offers 1000, customer proposes 800, worker counters 900, customer confirms 900."""
        req = make_request(customer)
        c, w = client_for(customer), client_for(worker.user)
        offer_id = data(w.post(offers_url(req), OFFER))["id"]

        resp = c.post(f"/api/v1/offers/{offer_id}/negotiate/", {"action": "counter", "amount": "800"})
        assert resp.status_code == 200, resp.json()
        assert data(resp)["offer"]["awaiting"] == "worker"

        # Customer cannot accept their own counter (needs worker consent).
        assert c.post(f"/api/v1/offers/{offer_id}/accept/").status_code == 409
        # Customer cannot counter twice in a row.
        assert c.post(f"/api/v1/offers/{offer_id}/negotiate/", {"amount": "700"}).status_code == 409

        resp = w.post(f"/api/v1/offers/{offer_id}/negotiate/", {"action": "counter", "amount": "900"})
        assert data(resp)["offer"]["current_price"] == "900.00"

        resp = c.post(f"/api/v1/offers/{offer_id}/accept/")
        assert resp.status_code == 201, resp.json()
        booking = data(resp)
        assert booking["agreed_price"] == "900.00"
        assert booking["status"] == "confirmed"

        history = data(c.get(f"/api/v1/offers/{offer_id}/negotiations/"))
        assert [(h["party"], h["action"], h["amount"]) for h in history] == [
            ("worker", "offer", "1000.00"),
            ("customer", "counter", "800.00"),
            ("worker", "counter", "900.00"),
            ("customer", "accept", "900.00"),
        ]
        req.refresh_from_db()
        assert req.status == ServiceRequest.Status.BOOKED

    def test_worker_agrees_then_customer_confirms(self, customer, worker, make_request, make_offer):
        req = make_request(customer)
        offer = make_offer(worker, req, "1000")
        c, w = client_for(customer), client_for(worker.user)
        c.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"amount": "850"})
        resp = w.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"action": "agree"})
        assert data(resp)["offer"]["awaiting"] == "customer"
        assert data(resp)["booking"] is None
        resp = c.post(f"/api/v1/offers/{offer.pk}/accept/")
        assert data(resp)["agreed_price"] == "850.00"

    def test_customer_agree_creates_booking(self, customer, worker, make_request, make_offer):
        req = make_request(customer)
        offer = make_offer(worker, req, "1200")
        resp = client_for(customer).post(f"/api/v1/offers/{offer.pk}/negotiate/", {"action": "agree"})
        assert resp.status_code == 200
        assert data(resp)["booking"]["agreed_price"] == "1200.00"

    def test_outsiders_cannot_negotiate_or_read(self, customer, worker, make_request, make_offer, make_customer,
                                                make_worker):
        offer = make_offer(worker, make_request(customer))
        for outsider in (make_customer(), make_worker().user):
            client = client_for(outsider)
            assert client.get(f"/api/v1/offers/{offer.pk}/").status_code == 404
            assert client.get(f"/api/v1/offers/{offer.pk}/negotiations/").status_code == 404
            assert client.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"amount": "500"}).status_code == 404
            assert client.post(f"/api/v1/offers/{offer.pk}/accept/").status_code == 404

    def test_counter_requires_amount_and_different_price(self, customer, worker, make_request, make_offer):
        offer = make_offer(worker, make_request(customer), "1000")
        c = client_for(customer)
        assert c.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"action": "counter"}).status_code == 400
        assert c.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"amount": "1000"}).status_code == 400

    def test_max_rounds(self, customer, worker, make_request, make_offer, settings):
        settings.KAAMNOW = {**settings.KAAMNOW, "MAX_NEGOTIATION_ROUNDS": 2}
        offer = make_offer(worker, make_request(customer), "1000")
        c, w = client_for(customer), client_for(worker.user)
        assert c.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"amount": "800"}).status_code == 200
        assert w.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"amount": "950"}).status_code == 200
        resp = c.post(f"/api/v1/offers/{offer.pk}/negotiate/", {"amount": "850"})
        assert resp.status_code == 400
        assert "Maximum" in resp.json()["error"]["message"]

    def test_worker_revises_price_via_patch(self, customer, worker, make_request, make_offer):
        offer = make_offer(worker, make_request(customer), "1000")
        resp = client_for(worker.user).patch(f"/api/v1/offers/{offer.pk}/", {"price": "950", "estimated_arrival_minutes": 20})
        assert resp.status_code == 200
        assert data(resp)["current_price"] == "950.00"
        assert offer.negotiations.filter(action=Negotiation.Action.REVISE).count() == 1

    def test_customer_cannot_patch_offer(self, customer, worker, make_request, make_offer):
        offer = make_offer(worker, make_request(customer), "1000")
        assert client_for(customer).patch(f"/api/v1/offers/{offer.pk}/", {"price": "10"}).status_code == 403


class TestAcceptReject:
    def test_accept_closes_other_offers_and_notifies(self, customer, make_request, make_worker, make_offer):
        req = make_request(customer)
        w1, w2, w3 = make_worker(), make_worker(), make_worker()
        o1, o2, o3 = make_offer(w1, req, "900"), make_offer(w2, req, "1000"), make_offer(w3, req, "1100")
        client_for(w3.user).post(f"/api/v1/offers/{o3.pk}/reject/", {"reason": "Busy"})  # withdrawn
        resp = client_for(customer).post(f"/api/v1/offers/{o1.pk}/accept/")
        assert resp.status_code == 201
        statuses = {o.pk: o.status for o in WorkerOffer.objects.filter(request=req)}
        assert statuses == {o1.pk: "accepted", o2.pk: "closed", o3.pk: "withdrawn"}
        assert Notification.objects.filter(user=w1.user, type="offer_accepted").exists()
        assert Notification.objects.filter(user=w2.user, type="offer_closed").exists()
        # Second accept on another offer is refused.
        assert client_for(customer).post(f"/api/v1/offers/{o2.pk}/accept/").status_code == 409
        assert Booking.objects.filter(request=req).count() == 1

    def test_customer_rejects(self, customer, worker, make_request, make_offer):
        offer = make_offer(worker, make_request(customer))
        resp = client_for(customer).post(f"/api/v1/offers/{offer.pk}/reject/", {"reason": "Too expensive"})
        assert data(resp)["status"] == "rejected"
        assert client_for(customer).post(f"/api/v1/offers/{offer.pk}/accept/").status_code == 409

    def test_worker_cannot_accept_own_offer(self, customer, worker, make_request, make_offer):
        offer = make_offer(worker, make_request(customer))
        assert client_for(worker.user).post(f"/api/v1/offers/{offer.pk}/accept/").status_code == 403

    def test_cannot_accept_offer_from_suspended_worker(self, customer, worker, make_request, make_offer):
        offer = make_offer(worker, make_request(customer))
        worker.user.is_suspended = True
        worker.user.save()
        assert client_for(customer).post(f"/api/v1/offers/{offer.pk}/accept/").status_code == 409
