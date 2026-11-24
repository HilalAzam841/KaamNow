from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing.models import FeaturedListing, FeaturedPlan, Payment
from apps.billing.services import expire_subscriptions_and_featured
from apps.dashboard.models import AuditLog
from conftest import LAHORE, client_for, data, jazzcash_callback

pytestmark = pytest.mark.django_db
URL = "/api/v1/featured/"


def feature(worker, category, api):
    plan = FeaturedPlan.objects.get(duration_days=7)
    resp = client_for(worker.user).post(URL, {"plan": plan.pk, "category": category.pk, "method": "jazzcash"})
    assert resp.status_code == 201, resp.json()
    payment = Payment.objects.get(pk=data(resp)["listing"]["payment"]["id"])
    api.post("/api/v1/payments/callbacks/jazzcash/", jazzcash_callback(payment), format="multipart")
    return FeaturedListing.objects.get(payment=payment)


class TestPurchase:
    def test_plans_public(self, api):
        assert [p["duration_days"] for p in data(api.get(f"{URL}plans/"))] == [7, 30]

    def test_purchase_activates_after_payment(self, api, worker, category, gateways):
        listing = feature(worker, category, api)
        assert listing.status == "active"
        assert listing.ends_at - listing.starts_at == timedelta(days=7)
        mine = data(client_for(worker.user).get(URL))["results"]
        assert mine[0]["status"] == "active"

    def test_must_offer_category(self, worker, other_category, gateways):
        plan = FeaturedPlan.objects.first()
        resp = client_for(worker.user).post(URL, {"plan": plan.pk, "category": other_category.pk, "method": "jazzcash"})
        assert resp.status_code == 400

    def test_unverified_cannot_buy(self, make_worker, category, gateways):
        w = make_worker(verified=False)
        plan = FeaturedPlan.objects.first()
        resp = client_for(w.user).post(URL, {"plan": plan.pk, "category": category.pk, "method": "jazzcash"})
        assert resp.status_code == 403

    def test_already_featured(self, api, worker, category, gateways):
        feature(worker, category, api)
        plan = FeaturedPlan.objects.first()
        resp = client_for(worker.user).post(URL, {"plan": plan.pk, "category": category.pk, "method": "jazzcash"})
        assert resp.status_code == 409

    def test_slot_limit(self, api, make_worker, category, gateways, settings):
        settings.KAAMNOW = {**settings.KAAMNOW, "MAX_FEATURED_PER_CATEGORY": 1}
        feature(make_worker(), category, api)
        plan = FeaturedPlan.objects.first()
        resp = client_for(make_worker().user).post(URL, {"plan": plan.pk, "category": category.pk,
                                                         "method": "jazzcash"})
        assert resp.status_code == 409
        assert "slots" in resp.json()["error"]["message"]


class TestSponsoredPlacement:
    def test_nearby_workers_sponsored_first_and_labelled(self, api, customer, make_worker, category, gateways):
        near = make_worker(name="Near")
        far = make_worker(name="Far", lat=Decimal("31.550000"))
        feature(far, category, api)
        results = data(client_for(customer).get("/api/v1/workers/nearby/", {
            "category": category.pk, "latitude": str(LAHORE[0]), "longitude": str(LAHORE[1])}))
        assert [(r["id"], r["is_sponsored"]) for r in results] == [(far.pk, True), (near.pk, False)]

    def test_service_listing_sponsored_first(self, api, make_worker, category, gateways):
        top = make_worker(name="Top rated")
        top.average_rating = Decimal("5.00")
        top.save()
        sponsored = make_worker(name="Sponsored")
        feature(sponsored, category, api)
        results = data(api.get("/api/v1/services/workers/", {"category": category.pk}))["results"]
        assert [(r["worker_id"], r["is_sponsored"]) for r in results] == [(sponsored.pk, True), (top.pk, False)]

    def test_expired_listing_not_sponsored(self, api, customer, make_worker, category, gateways):
        w = make_worker()
        listing = feature(w, category, api)
        FeaturedListing.objects.filter(pk=listing.pk).update(ends_at=timezone.now() - timedelta(seconds=1))
        assert expire_subscriptions_and_featured()["featured_listings"] == 1
        results = data(client_for(customer).get("/api/v1/workers/nearby/", {
            "category": category.pk, "latitude": str(LAHORE[0]), "longitude": str(LAHORE[1])}))
        assert results[0]["is_sponsored"] is False

    def test_admin_cancel(self, api, admin_user, worker, category, gateways):
        listing = feature(worker, category, api)
        client = client_for(admin_user)
        assert client.post(f"/api/v1/admin/featured-listings/{listing.pk}/cancel/", {}).status_code == 400
        resp = client.post(f"/api/v1/admin/featured-listings/{listing.pk}/cancel/", {"reason": "Fake reviews"})
        assert data(resp)["status"] == "cancelled"
        assert AuditLog.objects.filter(action="featured_cancelled").exists()
