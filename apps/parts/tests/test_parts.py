from decimal import Decimal

import pytest

from apps.billing.models import Commission, LedgerEntry, Payment, WorkerAdjustment
from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking
from apps.jobs.services import confirm_completion_by_customer
from apps.notifications.models import Notification
from apps.parts.models import MAX_PARTS, JobPart
from conftest import advance_to, client_for, data, jazzcash_callback, make_image

pytestmark = pytest.mark.django_db

PAY = "/api/v1/payments/"


def url(booking, suffix=""):
    return f"/api/v1/bookings/{booking.pk}/parts/{suffix}"


def add(worker, booking, name="Fan capacitor", quantity=1, unit_price="350", receipt=False):
    body = {"name": name, "quantity": quantity, "unit_price": unit_price}
    if receipt:
        body["receipt"] = make_image()
    return client_for(worker.user).post(url(booking), body, format="multipart")


@pytest.fixture
def working(customer, worker, make_booking):
    return advance_to(make_booking(customer, worker, "2000"), Booking.Status.IN_PROGRESS)


def approve(customer, booking, part_id):
    return client_for(customer).post(url(booking, f"{part_id}/approve/"))


class TestAddAndDecide:
    def test_worker_adds_customer_approves_and_total_grows(self, customer, worker, working):
        resp = add(worker, working, quantity=2, unit_price="350", receipt=True)
        assert resp.status_code == 201, resp.content
        part = data(resp)
        assert (part["total"], part["status"]) == ("700.00", "pending")
        assert part["receipt_url"] == f"/api/v1/bookings/{working.pk}/parts/{part['id']}/receipt/"
        assert Notification.objects.filter(user=customer, data__part_id=part["id"]).exists()

        booking = data(client_for(customer).get(f"/api/v1/bookings/{working.pk}/"))
        assert booking["parts"]["pending"] == 1 and booking["parts"]["can_decide"] is True
        assert booking["total_amount"] == "2000.00", "a pending part is not charged"

        assert data(approve(customer, working, part["id"]))["status"] == "approved"
        booking = data(client_for(customer).get(f"/api/v1/bookings/{working.pk}/"))
        assert (booking["parts_amount"], booking["total_amount"]) == ("700.00", "2700.00")
        assert Notification.objects.filter(user=worker.user, data__part_id=part["id"], title="Part approved").exists()

    def test_reject_needs_a_reason_and_is_not_charged(self, customer, worker, working):
        part = data(add(worker, working))
        c = client_for(customer)
        assert c.post(url(working, f"{part['id']}/reject/"), {"reason": ""}).status_code == 400
        body = data(c.post(url(working, f"{part['id']}/reject/"), {"reason": "I already have one"}))
        assert (body["status"], body["reject_reason"]) == ("rejected", "I already have one")
        working.refresh_from_db()
        assert working.parts_amount == Decimal("0.00")
        resp = approve(customer, working, part["id"])
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "part_decided"

    def test_roles(self, customer, worker, working, make_customer):
        as_customer = client_for(customer).post(url(working), {"name": "Pipe", "quantity": 1, "unit_price": "100"})
        assert as_customer.status_code == 403, "only the worker adds parts"
        part = data(add(worker, working))
        assert approve(worker.user, working, part["id"]).status_code == 403, "only the customer approves"
        outsider = make_customer()
        assert client_for(outsider).get(url(working)).status_code == 404
        assert approve(outsider, working, part["id"]).status_code == 404
        assert client_for(outsider).get(url(working, f"{part['id']}/receipt/")).status_code == 404

    def test_not_before_arrival(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = add(worker, booking)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "parts_closed"

    def test_limits(self, worker, working):
        assert add(worker, working, unit_price="60000").status_code == 400
        assert add(worker, working, quantity=0).status_code == 400
        for i in range(MAX_PARTS):
            assert add(worker, working, name=f"Part {i}", unit_price="10").status_code == 201
        resp = add(worker, working)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "parts_limit"

    def test_worker_removes_a_pending_part_only(self, customer, worker, working):
        a, b = data(add(worker, working)), data(add(worker, working, name="Wire"))
        approve(customer, working, b["id"])
        w = client_for(worker.user)
        assert client_for(customer).delete(url(working, f"{a['id']}/")).status_code == 403
        assert w.delete(url(working, f"{a['id']}/")).status_code == 204
        resp = w.delete(url(working, f"{b['id']}/"))
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "part_locked"

    def test_receipt_is_private(self, customer, worker, working, admin_user):
        part = data(add(worker, working, receipt=True))
        obj = JobPart.objects.get(pk=part["id"])
        with pytest.raises(NotImplementedError):
            obj.receipt.url  # noqa: B018
        assert client_for(customer).get(part["receipt_url"]).status_code == 200
        admin_parts = data(client_for(admin_user).get(f"/api/v1/admin/bookings/{working.pk}/parts/"))
        assert client_for(admin_user).get(admin_parts[0]["receipt_url"]).status_code == 200
        assert AuditLog.objects.filter(action=AuditLog.Action.PART_RECEIPT_VIEWED, actor=admin_user).count() == 1


class TestPayment:
    def _done(self, customer, worker, working, approve_part=True):
        part = data(add(worker, working, quantity=2, unit_price="350"))
        if approve_part:
            approve(customer, working, part["id"])
        return confirm_completion_by_customer(Booking.objects.get(pk=working.pk), customer), part

    def test_cannot_pay_while_a_part_waits(self, customer, worker, working):
        booking, _ = self._done(customer, worker, working, approve_part=False)
        resp = client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"})
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "parts_pending"

    def test_no_changes_once_payment_started(self, customer, worker, working):
        booking, _ = self._done(customer, worker, working)
        data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}))
        resp = add(worker, booking)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "parts_closed"

    def test_cash_payment_includes_parts_without_commission(self, customer, worker, working):
        booking, _ = self._done(customer, worker, working)
        payment = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}))
        assert payment["amount"] == "2700.00"
        assert client_for(worker.user).post(f"{PAY}{payment['id']}/confirm/").status_code == 200
        commission = Commission.objects.get(booking=booking)
        assert (commission.gross_amount, commission.commission_amount) == (Decimal("2000.00"), Decimal("200.00"))
        assert LedgerEntry.objects.get(booking=booking, entry_type="parts").amount == Decimal("700.00")
        assert not WorkerAdjustment.objects.exists(), "the worker already holds the cash"
        receipt = data(client_for(customer).get(f"{PAY}{payment['id']}/receipt/"))
        assert {"label": "Part: Fan capacitor × 2", "amount": "700.00"} in receipt["lines"]
        assert receipt["total"] == "2700.00"

    def test_online_payment_owes_the_parts_to_the_worker(self, api, customer, worker, working, gateways):
        booking, _ = self._done(customer, worker, working)
        body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash"}))
        payment = Payment.objects.get(pk=body["id"])
        assert payment.amount == Decimal("2700.00")
        assert api.post(f"{PAY}callbacks/jazzcash/", jazzcash_callback(payment), format="multipart").status_code == 200
        adj = WorkerAdjustment.objects.get(worker=worker)
        assert adj.amount == Decimal("700.00")
        wallet = data(client_for(worker.user).get(f"{PAY}wallet/"))
        assert wallet["balance"] == "2500.00"  # 1800 earning (2000 less 10%) + 700 parts
