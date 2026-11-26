from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing import wallet
from apps.billing.models import LedgerEntry, Payment, PlatformSettings, WorkerAdjustment
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.tips.models import Tip
from conftest import client_for, data, jazzcash_callback

JC_CB = "/api/v1/payments/callbacks/jazzcash/"


def give(user, booking, amount="200", method="cash", message=""):
    return client_for(user).post(f"/api/v1/bookings/{booking.pk}/tip/",
                                 {"amount": amount, "method": method, "message": message}, format="json")


@pytest.fixture
def done(customer, worker, completed_booking_factory):
    return completed_booking_factory(customer, worker)


@pytest.mark.django_db
class TestGiveTip:
    def test_cash_tip_then_worker_confirms(self, customer, worker, done):
        r = give(customer, done, "250", message="Great work, thank you")
        assert r.status_code == 201, r.json()
        body = data(r)
        assert body["checkout"] is None
        tip = Tip.objects.get(pk=body["tip"]["id"])
        assert tip.status == Tip.Status.PENDING and tip.amount == Decimal("250.00")
        assert Notification.objects.filter(user=worker.user, title="Confirm your cash tip").exists()

        r = client_for(worker.user).post(f"/api/v1/tips/{tip.pk}/confirm-cash/")
        assert data(r)["status"] == "paid"
        tip.refresh_from_db()
        assert tip.payment.status == Payment.Status.COMPLETED and tip.payment.purpose == Payment.Purpose.TIP
        entry = LedgerEntry.objects.get(payment=tip.payment)
        assert entry.entry_type == LedgerEntry.EntryType.TIP and entry.amount == Decimal("250.00")
        assert not WorkerAdjustment.objects.filter(worker=worker).exists(), "the worker already holds the cash"
        n = Notification.objects.get(user=worker.user, title="You got a tip!")
        assert "Great work, thank you" in n.body

    def test_whole_tip_goes_to_the_worker_online(self, api, customer, worker, done, gateways):
        before = wallet.summary(worker)["balance"]
        body = data(give(customer, done, "300", method="jazzcash"))
        assert body["checkout"]["url"].startswith("https://sandbox.jazzcash")
        tip = Tip.objects.get(pk=body["tip"]["id"])
        assert tip.status == Tip.Status.PENDING
        assert api.post(JC_CB, jazzcash_callback(tip.payment), format="multipart").status_code == 200
        tip.refresh_from_db()
        assert tip.status == Tip.Status.PAID and tip.paid_at
        adj = WorkerAdjustment.objects.get(worker=worker)
        assert adj.amount == Decimal("300.00"), "no commission on tips"
        assert not LedgerEntry.objects.filter(payment=tip.payment,
                                              entry_type=LedgerEntry.EntryType.PLATFORM_COMMISSION).exists()
        assert wallet.summary(worker)["balance"] == before + Decimal("300.00")

    def test_client_cannot_mark_online_tip_paid(self, customer, worker, done, gateways):
        tip = Tip.objects.get(pk=data(give(customer, done, "300", method="jazzcash"))["tip"]["id"])
        r = client_for(worker.user).post(f"/api/v1/tips/{tip.pk}/confirm-cash/")
        assert r.status_code == 400
        tip.refresh_from_db()
        assert tip.status == Tip.Status.PENDING

    def test_failed_callback_leaves_tip_unpaid_and_retry_works(self, api, customer, worker, done, gateways):
        tip = Tip.objects.get(pk=data(give(customer, done, "300", method="jazzcash"))["tip"]["id"])
        api.post(JC_CB, jazzcash_callback(tip.payment, code="999"), format="multipart")
        tip.refresh_from_db()
        assert tip.status == Tip.Status.PENDING and tip.payment.status == Payment.Status.FAILED
        assert give(customer, done, "150", method="cash").status_code == 201
        tip.refresh_from_db()
        assert tip.amount == Decimal("150.00") and tip.method == "cash"
        assert Tip.objects.filter(booking=done).count() == 1

    def test_amount_mismatch_is_disputed_not_paid(self, api, customer, worker, done, gateways):
        tip = Tip.objects.get(pk=data(give(customer, done, "300", method="jazzcash"))["tip"]["id"])
        api.post(JC_CB, jazzcash_callback(tip.payment, amount=Decimal("3000")), format="multipart")
        tip.refresh_from_db()
        assert tip.status == Tip.Status.PENDING and tip.payment.status == Payment.Status.DISPUTED
        assert not WorkerAdjustment.objects.filter(worker=worker).exists()

    def test_only_one_paid_tip_per_booking(self, customer, worker, done):
        tip = Tip.objects.get(pk=data(give(customer, done))["tip"]["id"])
        client_for(worker.user).post(f"/api/v1/tips/{tip.pk}/confirm-cash/")
        r = give(customer, done)
        assert r.status_code == 409 and r.json()["error"]["code"] == "already_tipped"

    def test_limits(self, customer, done):
        assert give(customer, done, "10").status_code == 400
        assert give(customer, done, "5001").status_code == 400
        cfg = PlatformSettings.load()
        cfg.tip_max_amount = Decimal("1000")
        cfg.save()
        assert give(customer, done, "1500").status_code == 400
        assert give(customer, done, "1000").status_code == 201

    def test_only_after_completion_and_inside_the_window(self, customer, worker, make_booking, done):
        open_booking = make_booking(customer, worker)
        assert give(customer, open_booking).status_code == 409
        Booking.objects.filter(pk=done.pk).update(completed_at=timezone.now() - timedelta(days=8))
        r = give(customer, done)
        assert r.status_code == 409 and r.json()["error"]["code"] == "tip_window_closed"

    def test_switched_off(self, customer, done):
        cfg = PlatformSettings.load()
        cfg.tips_enabled = False
        cfg.save()
        assert give(customer, done).status_code == 400
        assert data(client_for(customer).get(f"/api/v1/bookings/{done.pk}/"))["can_tip"] is False

    def test_only_the_customer_can_tip(self, worker, make_customer, done):
        assert give(worker.user, done).status_code == 403
        assert give(make_customer(), done).status_code == 404


@pytest.mark.django_db
class TestWorkerAndViews:
    def test_worker_says_cash_not_received(self, customer, worker, done):
        tip = Tip.objects.get(pk=data(give(customer, done))["tip"]["id"])
        r = client_for(worker.user).post(f"/api/v1/tips/{tip.pk}/not-received/")
        assert data(r)["status"] == "cancelled"
        tip.refresh_from_db()
        assert tip.payment.status == Payment.Status.FAILED
        assert Notification.objects.filter(user=customer, title="Cash tip not received").exists()
        booking = data(client_for(customer).get(f"/api/v1/bookings/{done.pk}/"))
        assert booking["tip"] is None and booking["can_tip"] is True

    def test_customer_cannot_confirm_own_cash_tip(self, customer, done):
        tip = Tip.objects.get(pk=data(give(customer, done))["tip"]["id"])
        assert client_for(customer).post(f"/api/v1/tips/{tip.pk}/confirm-cash/").status_code == 403

    def test_booking_shows_tip_to_both_sides(self, customer, worker, done):
        assert data(client_for(customer).get(f"/api/v1/bookings/{done.pk}/"))["can_tip"] is True
        give(customer, done, "200", message="Thanks")
        for user in (customer, worker.user):
            b = data(client_for(user).get(f"/api/v1/bookings/{done.pk}/"))
            assert b["tip"]["amount"] == "200.00" and b["tip"]["status"] == "pending"
        assert data(client_for(worker.user).get(f"/api/v1/bookings/{done.pk}/"))["can_tip"] is False

    def test_lists_and_summary_are_private(self, customer, worker, make_worker, make_customer, done):
        tip = Tip.objects.get(pk=data(give(customer, done, "200"))["tip"]["id"])
        client_for(worker.user).post(f"/api/v1/tips/{tip.pk}/confirm-cash/")
        rows = data(client_for(worker.user).get("/api/v1/tips/"))["results"]
        assert [r["id"] for r in rows] == [tip.pk]
        assert rows[0]["customer_name"] == customer.full_name.split(" ")[0]
        assert data(client_for(worker.user).get("/api/v1/tips/summary/")) == {"count": 1, "total": "200.00"}
        assert data(client_for(make_customer()).get("/api/v1/tips/"))["results"] == []
        other = make_worker()
        assert data(client_for(other.user).get("/api/v1/tips/summary/"))["count"] == 0
        assert client_for(other.user).post(f"/api/v1/tips/{tip.pk}/confirm-cash/").status_code == 404

    def test_receipt_for_an_online_tip(self, api, customer, worker, done, gateways):
        tip = Tip.objects.get(pk=data(give(customer, done, "300", method="jazzcash"))["tip"]["id"])
        api.post(JC_CB, jazzcash_callback(tip.payment), format="multipart")
        r = data(client_for(customer).get(f"/api/v1/payments/{tip.payment_id}/receipt/"))
        assert r["purpose"] == "tip" and r["booking"] == done.pk and r["total"] == "300.00"

    def test_admin_list_and_app_config(self, customer, admin_user, done):
        give(customer, done)
        rows = data(client_for(admin_user).get("/api/v1/admin/tips/"))["results"]
        assert rows[0]["customer_name"] == customer.full_name
        assert client_for(customer).get("/api/v1/admin/tips/").status_code == 403
        cfg = data(client_for(customer).get("/api/v1/app/config/"))["tips"]
        assert cfg == {"enabled": True, "min": "50.00", "max": "5000.00", "window_days": 7,
                       "suggestions": ["100.00", "200.00", "500.00"]}
