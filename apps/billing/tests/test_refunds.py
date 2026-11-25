"""Refunds of booking payments and resolving disputed payments (admin)."""

from decimal import Decimal

import pytest

from apps.billing.models import LedgerEntry, Payment, Refund, WorkerAdjustment
from apps.dashboard.models import AuditLog
from apps.notifications.models import Notification
from apps.support.models import Complaint
from conftest import client_for, data

from .test_wallet import JAZZCASH_ACCOUNT, PAYOUTS, error, wallet

pytestmark = pytest.mark.django_db

ADMIN_PAYMENTS = "/api/v1/admin/payments/"
REFUND = {"method": "gateway", "reason": "Job not finished properly", "reference": "JC-RF-1001"}


def payment_of(booking):
    return Payment.objects.get(booking=booking, status="completed")


def disputed(customer, worker, completed_booking_factory, gateways, price="2000"):
    booking = completed_booking_factory(customer, worker, price)
    body = data(client_for(customer).post("/api/v1/payments/", {"booking": booking.pk, "method": "jazzcash"}))
    Payment.objects.filter(pk=body["id"]).update(
        status=Payment.Status.DISPUTED, failure_reason="Gateway reported success after the payment was closed.",
        gateway_transaction_id="T2026112500001",
    )
    return Payment.objects.get(pk=body["id"])


class TestRefund:
    def test_partial_refund_charges_worker_share_and_is_audited(self, admin_user, customer, worker, paid_online):
        booking = paid_online("2000")  # worker earns 1800 (90%)
        payment = payment_of(booking)
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/",
                                           {**REFUND, "amount": "500", "charge_worker": True})
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert (body["amount"], body["worker_share"]) == ("500.00", "450.00")
        payment.refresh_from_db()
        assert payment.status == "completed" and payment.refunded_amount == Decimal("500.00")
        adj = WorkerAdjustment.objects.get(refund_id=body["id"])
        assert adj.amount == Decimal("-450.00")
        w = wallet(worker)
        assert (w["earnings_held"], w["commission_owed"], w["balance"]) == ("1800.00", "450.00", "1350.00")
        entry = LedgerEntry.objects.get(refund_id=body["id"])
        assert entry.entry_type == "customer_refund" and entry.amount == Decimal("500.00")
        log = AuditLog.objects.get(action="payment_refunded")
        assert log.target_id == str(payment.pk) and log.metadata["reference"] == "JC-RF-1001"
        assert Notification.objects.filter(user=customer, title="Refund sent").exists()
        assert Notification.objects.filter(user=worker.user, title="Refund charged to your wallet").exists()
        # The customer sees what was refunded on their payment.
        mine = data(client_for(customer).get(f"/api/v1/payments/{payment.pk}/"))
        assert mine["refunded_amount"] == "500.00"

    def test_platform_can_absorb_the_refund(self, admin_user, worker, paid_online):
        payment = payment_of(paid_online("2000"))
        body = data(client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/", {**REFUND, "amount": "2000"}))
        assert body["worker_share"] == "0.00"
        assert not WorkerAdjustment.objects.exists()
        assert wallet(worker)["balance"] == "1800.00"

    def test_cannot_refund_more_than_paid(self, admin_user, paid_online):
        payment = payment_of(paid_online("2000"))
        url = f"{ADMIN_PAYMENTS}{payment.pk}/refund/"
        assert client_for(admin_user).post(url, {**REFUND, "amount": "1500"}).status_code == 201
        resp = client_for(admin_user).post(url, {**REFUND, "amount": "600", "reference": "JC-RF-1002"})
        assert resp.status_code == 400
        assert "500" in error(resp)["message"]
        assert Refund.objects.count() == 1

    def test_pending_payment_cannot_be_refunded(self, admin_user, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker, "2000")
        body = data(client_for(customer).post("/api/v1/payments/", {"booking": booking.pk, "method": "cash"}))
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{body['id']}/refund/", {**REFUND, "amount": "100"})
        assert resp.status_code == 409

    def test_cash_job_refund_adds_to_what_worker_owes(self, admin_user, worker, paid_cash):
        payment = payment_of(paid_cash("1000"))  # worker owes 100 commission
        client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/",
                                    {**REFUND, "method": "cash", "amount": "1000", "charge_worker": True})
        w = wallet(worker)
        assert (w["commission_owed"], w["balance"]) == ("1000.00", "-1000.00")

    def test_payout_settles_the_adjustment(self, admin_user, worker, paid_online):
        payment = payment_of(paid_online("2000"))
        client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/",
                                    {**REFUND, "amount": "200", "charge_worker": True})
        payout = data(client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT))
        assert (payout["amount"], payout["commission_amount"]) == ("1620.00", "180.00")
        adj = WorkerAdjustment.objects.get()
        assert adj.settlement_id == payout["id"]
        assert wallet(worker)["balance"] == "0.00"
        # Cancelling gives it back.
        client_for(worker.user).post(f"{PAYOUTS}{payout['id']}/cancel/")
        adj.refresh_from_db()
        assert adj.settlement_id is None and wallet(worker)["balance"] == "1620.00"

    def test_complaint_must_match_booking(self, admin_user, customer, worker, paid_online):
        booking, other = paid_online("2000"), paid_online("1000")
        complaint = Complaint.objects.create(raised_by=customer, booking=other, category="service_quality",
                                             subject="Leak", description="Still leaking")
        payment = payment_of(booking)
        url = f"{ADMIN_PAYMENTS}{payment.pk}/refund/"
        resp = client_for(admin_user).post(url, {**REFUND, "amount": "100", "complaint": complaint.pk})
        assert resp.status_code == 400
        complaint.booking = booking
        complaint.save()
        assert client_for(admin_user).post(url, {**REFUND, "amount": "100", "complaint": complaint.pk}).status_code == 201

    def test_admin_only(self, customer, worker, paid_online):
        payment = payment_of(paid_online("2000"))
        for user in (customer, worker.user):
            assert client_for(user).get(ADMIN_PAYMENTS).status_code == 403
            assert client_for(user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/",
                                         {**REFUND, "amount": "100"}).status_code == 403

    def test_list_filters(self, admin_user, paid_online, paid_cash):
        online = payment_of(paid_online("2000"))
        payment_of(paid_cash("1000"))
        client_for(admin_user).post(f"{ADMIN_PAYMENTS}{online.pk}/refund/", {**REFUND, "amount": "100"})
        rows = data(client_for(admin_user).get(ADMIN_PAYMENTS, {"refunded": "true"}))["results"]
        assert [r["id"] for r in rows] == [online.pk]
        assert rows[0]["refundable_amount"] == "1900.00" and rows[0]["refunds"][0]["reference"] == "JC-RF-1001"
        assert rows[0]["payer_name"] and rows[0]["worker_name"]
        assert len(data(client_for(admin_user).get(ADMIN_PAYMENTS, {"method": "cash"}))["results"]) == 1


class TestDisputed:
    def test_accept_counts_as_the_booking_payment(self, admin_user, customer, worker, completed_booking_factory,
                                                  gateways):
        payment = disputed(customer, worker, completed_booking_factory, gateways)
        rows = data(client_for(admin_user).get(ADMIN_PAYMENTS, {"status": "disputed"}))["results"]
        assert [r["id"] for r in rows] == [payment.pk] and rows[0]["gateway_transaction_id"] == "T2026112500001"
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/resolve/",
                                           {"resolution": "accept", "note": "Found in JazzCash portal"})
        assert resp.status_code == 200, resp.json()
        assert data(resp)["status"] == "completed"
        assert wallet(worker)["earnings_held"] == "1800.00"
        assert AuditLog.objects.get(action="payment_resolved").metadata["resolution"] == "accept"

    def test_accept_refused_when_booking_already_paid(self, admin_user, customer, worker, completed_booking_factory,
                                                      gateways):
        payment = disputed(customer, worker, completed_booking_factory, gateways)
        other = data(client_for(customer).post("/api/v1/payments/", {"booking": payment.booking_id, "method": "cash"}))
        client_for(worker.user).post(f"/api/v1/payments/{other['id']}/confirm/")
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/resolve/",
                                           {"resolution": "accept", "note": "x"})
        assert resp.status_code == 409
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/resolve/",
                                           {"resolution": "refund", "note": "Paid twice", "method": "gateway",
                                            "reference": "JC-RF-2001"})
        assert resp.status_code == 200
        body = data(resp)
        assert body["status"] == "refunded" and body["refunded_amount"] == "2000.00"
        assert Notification.objects.filter(user=customer, title="Refund sent").exists()
        assert wallet(worker)["balance"] == "-200.00"  # only the cash job's commission, the refund costs nothing

    def test_refund_needs_reference(self, admin_user, customer, worker, completed_booking_factory, gateways):
        payment = disputed(customer, worker, completed_booking_factory, gateways)
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/resolve/",
                                           {"resolution": "refund", "note": "x", "method": "gateway"})
        assert resp.status_code == 400

    def test_reject(self, admin_user, customer, worker, completed_booking_factory, gateways):
        payment = disputed(customer, worker, completed_booking_factory, gateways)
        resp = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/resolve/",
                                           {"resolution": "reject", "note": "No money in the portal"})
        assert data(resp)["status"] == "failed"
        assert Notification.objects.filter(user=customer, title="Payment not received").exists()
        # Resolving twice is refused.
        again = client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/resolve/",
                                            {"resolution": "reject", "note": "x"})
        assert again.status_code == 409
        # The customer can pay again.
        assert client_for(customer).post("/api/v1/payments/", {"booking": payment.booking_id,
                                                                "method": "cash"}).status_code == 201

    def test_admin_balances_include_adjustments(self, admin_user, worker, paid_online):
        payment = payment_of(paid_online("1000"))
        client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/",
                                    {**REFUND, "amount": "1000", "charge_worker": True})
        rows = data(client_for(admin_user).get("/api/v1/admin/worker-balances/"))
        assert rows == []  # 900 held, 900 charged: nothing to settle
