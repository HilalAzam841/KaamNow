from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing.models import Commission, LedgerEntry, Payment, SubscriptionPlan, WorkerSubscription
from apps.billing.services import expire_subscriptions_and_featured
from apps.dashboard.models import AuditLog
from conftest import client_for, data, jazzcash_callback

pytestmark = pytest.mark.django_db
SUBS = "/api/v1/subscriptions/"


def plan(slug):
    return SubscriptionPlan.objects.get(slug=slug)


def buy(worker, slug, api, gateways_fixture=None):
    resp = client_for(worker.user).post(SUBS, {"plan": plan(slug).pk, "method": "jazzcash"})
    assert resp.status_code == 201, resp.json()
    payment = Payment.objects.get(pk=data(resp)["subscription"]["payment"]["id"])
    assert api.post("/api/v1/payments/callbacks/jazzcash/", jazzcash_callback(payment), format="multipart").status_code == 200
    return WorkerSubscription.objects.get(payment=payment)


class TestPlans:
    def test_public_plan_list(self, api):
        plans = data(api.get(f"{SUBS}plans/"))
        assert [p["slug"] for p in plans] == ["free", "professional", "premium"]
        assert plans[0]["is_default"] and plans[0]["price"] == "0.00"
        assert plans[1]["commission_percent"] == "8.00"

    def test_default_is_free(self, worker):
        body = data(client_for(worker.user).get(f"{SUBS}my-subscription/"))
        assert body["plan"]["slug"] == "free"
        assert body["subscription"] is None
        assert body["offers_remaining_today"] == 10
        assert body["commission_percent"] == "10.00"

    def test_customer_cannot_view(self, customer):
        assert client_for(customer).get(f"{SUBS}my-subscription/").status_code == 403


class TestDailyOfferLimit:
    def test_free_plan_limit_enforced(self, customer, worker, make_request, make_offer):
        p = plan("free")
        p.daily_offer_limit = 2
        p.save()
        for _ in range(2):
            make_offer(worker, make_request(customer))
        resp = client_for(worker.user).post(f"/api/v1/requests/{make_request(customer).pk}/offers/",
                                            {"price": "1000", "estimated_arrival_minutes": 30})
        assert resp.status_code == 403
        assert "Upgrade" in resp.json()["error"]["message"]

    def test_paid_plan_unlimited(self, api, customer, worker, make_request, make_offer, gateways):
        p = plan("free")
        p.daily_offer_limit = 1
        p.save()
        buy(worker, "professional", api)
        for _ in range(3):
            make_offer(worker, make_request(customer))
        assert data(client_for(worker.user).get(f"{SUBS}my-subscription/"))["offers_remaining_today"] is None


class TestSubscribe:
    def test_paid_plan_requires_verified_payment(self, api, worker, gateways):
        resp = client_for(worker.user).post(SUBS, {"plan": plan("premium").pk, "method": "jazzcash"})
        body = data(resp)
        assert body["subscription"]["status"] == "pending_payment"
        assert body["checkout"]["fields"]["pp_Amount"] == "300000"
        # Not active until the gateway callback is verified.
        assert data(client_for(worker.user).get(f"{SUBS}my-subscription/"))["plan"]["slug"] == "free"
        payment = Payment.objects.get(pk=body["subscription"]["payment"]["id"])
        api.post("/api/v1/payments/callbacks/jazzcash/", jazzcash_callback(payment), format="multipart")
        mine = data(client_for(worker.user).get(f"{SUBS}my-subscription/"))
        assert mine["plan"]["slug"] == "premium"
        assert mine["subscription"]["status"] == "active"
        assert LedgerEntry.objects.get(payment=payment).entry_type == "subscription_revenue"

    def test_subscription_commission_applies(self, api, customer, worker, gateways, completed_booking_factory):
        buy(worker, "professional", api)
        booking = completed_booking_factory(customer, worker, "2000")
        commission = Commission.objects.get(booking=booking)
        assert (commission.rate_percent, commission.commission_amount) == (Decimal("8.00"), Decimal("160.00"))

    def test_renewal_extends(self, api, worker, gateways):
        first = buy(worker, "professional", api)
        second = buy(worker, "professional", api)
        first.refresh_from_db()
        assert first.status == "expired"
        assert second.ends_at - first.ends_at == timedelta(days=30)

    def test_switch_plan_replaces(self, api, worker, gateways):
        buy(worker, "professional", api)
        premium = buy(worker, "premium", api)
        assert WorkerSubscription.objects.filter(worker=worker, status="active").get() == premium

    def test_cash_not_allowed(self, worker):
        resp = client_for(worker.user).post(SUBS, {"plan": plan("premium").pk})
        assert resp.status_code == 400

    def test_unverified_worker(self, make_worker, gateways):
        w = make_worker(verified=False)
        assert client_for(w.user).post(SUBS, {"plan": plan("premium").pk, "method": "jazzcash"}).status_code == 403

    def test_customer_cannot_subscribe(self, customer, gateways):
        assert client_for(customer).post(SUBS, {"plan": plan("premium").pk, "method": "jazzcash"}).status_code == 403

    def test_history(self, api, worker, gateways):
        buy(worker, "professional", api)
        assert data(client_for(worker.user).get(f"{SUBS}history/"))["count"] == 1

    def test_expiry_task_returns_worker_to_free(self, api, worker, gateways):
        sub = buy(worker, "premium", api)
        WorkerSubscription.objects.filter(pk=sub.pk).update(ends_at=timezone.now() - timedelta(seconds=1))
        assert expire_subscriptions_and_featured()["subscriptions"] == 1
        assert data(client_for(worker.user).get(f"{SUBS}my-subscription/"))["plan"]["slug"] == "free"

    def test_badge_on_public_card(self, api, worker, gateways):
        buy(worker, "premium", api)
        assert data(api.get(f"/api/v1/workers/{worker.pk}/"))["plan_badge"] == "PREMIUM"


class TestAdminSubscriptions:
    def test_manual_activation_is_audited(self, admin_user, worker, gateways):
        sub_id = data(client_for(worker.user).post(SUBS, {"plan": plan("premium").pk, "method": "jazzcash"}))[
            "subscription"]["id"]
        resp = client_for(admin_user).post(f"/api/v1/admin/subscriptions/{sub_id}/activate/")
        assert resp.status_code == 200
        assert data(resp)["status"] == "active"
        assert AuditLog.objects.filter(action="subscription_activated", target_id=str(sub_id)).exists()
        sub = WorkerSubscription.objects.get(pk=sub_id)
        assert sub.payment.status == "failed"  # the abandoned checkout is closed

    def test_plan_management(self, admin_user, customer):
        client = client_for(admin_user)
        resp = client.post("/api/v1/admin/subscription-plans/", {
            "name": "Starter", "slug": "starter", "price": "500", "duration_days": 30, "commission_percent": "9.5",
            "daily_offer_limit": 25, "benefits": ["25 offers per day"],
        }, format="json")
        assert resp.status_code == 201, resp.json()
        pid = data(resp)["id"]
        assert client.patch(f"/api/v1/admin/subscription-plans/{pid}/", {"price": "600"}).status_code == 200
        assert client.patch(f"/api/v1/admin/subscription-plans/{pid}/", {"is_default": True}).status_code == 400
        assert AuditLog.objects.filter(action="plan_changed").count() == 2
        assert client_for(customer).post("/api/v1/admin/subscription-plans/", {"name": "x"}).status_code == 403
