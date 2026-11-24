from decimal import Decimal

import pytest

from apps.billing.models import Commission, LedgerEntry, Payment, PlatformSettings
from apps.jobs.models import Booking
from apps.jobs.services import confirm_completion_by_customer
from conftest import advance_to, client_for, data

pytestmark = pytest.mark.django_db
URL = "/api/v1/payments/"


@pytest.fixture
def completed_booking(customer, worker, make_booking):
    booking = advance_to(make_booking(customer, worker, "2000"), Booking.Status.IN_PROGRESS)
    return confirm_completion_by_customer(booking, customer)


class TestRecordPayment:
    def test_cash_payment_uses_locked_price(self, customer, completed_booking):
        resp = client_for(customer).post(URL, {"booking": completed_booking.pk, "method": "cash", "amount": "1"})
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["amount"] == "2000.00"  # client-sent amount ignored
        assert body["status"] == "pending"
        assert body["reference"].startswith("KN") and body["reference"].isalnum()

    def test_not_before_completion(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(customer).post(URL, {"booking": booking.pk, "method": "cash"}).status_code == 409

    @pytest.mark.parametrize("method", ["jazzcash", "easypaisa"])
    def test_online_methods_not_trusted_from_client(self, customer, completed_booking, method):
        resp = client_for(customer).post(URL, {"booking": completed_booking.pk, "method": method})
        assert resp.status_code == 400
        assert not Payment.objects.exists()

    def test_invalid_method(self, customer, completed_booking):
        assert client_for(customer).post(URL, {"booking": completed_booking.pk, "method": "bitcoin"}).status_code == 400

    def test_duplicate_payment(self, customer, completed_booking):
        c = client_for(customer)
        assert c.post(URL, {"booking": completed_booking.pk}).status_code == 201
        assert c.post(URL, {"booking": completed_booking.pk}).status_code == 409

    def test_only_booking_customer_can_pay(self, make_customer, completed_booking):
        assert client_for(make_customer()).post(URL, {"booking": completed_booking.pk}).status_code == 403

    def test_worker_cannot_create_payment(self, worker, completed_booking):
        assert client_for(worker.user).post(URL, {"booking": completed_booking.pk}).status_code == 403


class TestConfirmPayment:
    def test_worker_confirms_and_ledger_balances(self, customer, worker, completed_booking):
        payment_id = data(client_for(customer).post(URL, {"booking": completed_booking.pk}))["id"]
        resp = client_for(worker.user).post(f"{URL}{payment_id}/confirm/")
        assert resp.status_code == 200
        assert data(resp)["status"] == "completed"
        entries = {e.entry_type: e.amount for e in LedgerEntry.objects.filter(payment_id=payment_id)}
        assert entries == {
            "customer_payment": Decimal("2000.00"),
            "platform_commission": Decimal("200.00"),
            "worker_earning": Decimal("1800.00"),
        }
        assert entries["platform_commission"] + entries["worker_earning"] == entries["customer_payment"]
        assert client_for(worker.user).post(f"{URL}{payment_id}/confirm/").status_code == 409

    def test_customer_cannot_confirm_own_cash(self, customer, completed_booking):
        payment_id = data(client_for(customer).post(URL, {"booking": completed_booking.pk}))["id"]
        assert client_for(customer).post(f"{URL}{payment_id}/confirm/").status_code == 403

    def test_other_worker_cannot_see_or_confirm(self, customer, completed_booking, make_worker):
        payment_id = data(client_for(customer).post(URL, {"booking": completed_booking.pk}))["id"]
        other = client_for(make_worker().user)
        assert other.get(f"{URL}{payment_id}/").status_code == 404
        assert other.post(f"{URL}{payment_id}/confirm/").status_code == 404

    def test_list_scoped(self, customer, worker, completed_booking, make_customer):
        client_for(customer).post(URL, {"booking": completed_booking.pk})
        assert data(client_for(customer).get(URL))["count"] == 1
        assert data(client_for(worker.user).get(URL))["count"] == 1
        assert data(client_for(make_customer()).get(URL))["count"] == 0


class TestCommissionConfig:
    def test_rate_change_applies_to_new_completions_only(self, customer, worker, make_booking, completed_booking,
                                                         admin_user):
        resp = client_for(admin_user).patch("/api/v1/admin/settings/commission/", {"commission_percent": "15.00"})
        assert resp.status_code == 200
        assert PlatformSettings.load().commission_percent == Decimal("15.00")
        # Existing commission unchanged.
        assert Commission.objects.get(booking=completed_booking).rate_percent == Decimal("10.00")
        booking = advance_to(make_booking(customer, worker, "1000"), Booking.Status.IN_PROGRESS)
        confirm_completion_by_customer(booking, customer)
        new = Commission.objects.get(booking=booking)
        assert (new.rate_percent, new.commission_amount, new.worker_earning) == (
            Decimal("15.00"), Decimal("150.00"), Decimal("850.00"))

    def test_rate_bounds(self, admin_user):
        assert client_for(admin_user).patch("/api/v1/admin/settings/commission/",
                                            {"commission_percent": "75"}).status_code == 400

    def test_non_admin_cannot_change_rate(self, customer):
        assert client_for(customer).patch("/api/v1/admin/settings/commission/",
                                          {"commission_percent": "1"}).status_code == 403


class TestEarnings:
    def test_worker_earnings_summary(self, worker, completed_booking):
        resp = client_for(worker.user).get(f"{URL}earnings/")
        assert resp.status_code == 200
        body = data(resp)
        assert body["completed_jobs"] == 1
        assert body["gross_amount"] == "2000.00"
        assert body["commission_amount"] == "200.00"
        assert body["net_earnings"] == "1800.00"
        assert body["commission_pending"] == "200.00"

    def test_customer_cannot_view_earnings(self, customer):
        assert client_for(customer).get(f"{URL}earnings/").status_code == 403
