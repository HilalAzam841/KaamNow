"""Worker wallet: payouts of online earnings and settlement of cash commission."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing.models import Commission, LedgerEntry, Payment, PlatformSettings, WorkerSettlement
from apps.billing.services import expire_stale_online_payments
from apps.dashboard.models import AuditLog
from apps.notifications.models import Notification
from conftest import client_for, data, jazzcash_callback

pytestmark = pytest.mark.django_db

PAY = "/api/v1/payments/"
WALLET = "/api/v1/payments/wallet/"
PAYOUTS = "/api/v1/payments/payouts/"
PAY_COMMISSION = "/api/v1/payments/commission/pay/"
JC_CB = "/api/v1/payments/callbacks/jazzcash/"
ADMIN_SETTLEMENTS = "/api/v1/admin/settlements/"
JAZZCASH_ACCOUNT = {"method": "jazzcash", "account_title": "Ali Raza", "account_number": "0300 1234567"}


@pytest.fixture
def paid_cash(customer, worker, completed_booking_factory):
    """A job paid in cash: the worker holds the money and owes 10% commission."""

    def _make(price="2000"):
        booking = completed_booking_factory(customer, worker, price)
        payment = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}))
        assert client_for(worker.user).post(f"{PAY}{payment['id']}/confirm/").status_code == 200
        return booking

    return _make


@pytest.fixture
def paid_online(api, customer, worker, completed_booking_factory, gateways):
    """A job paid with JazzCash: KaamNow holds the money and owes the worker 90%."""

    def _make(price="2000"):
        booking = completed_booking_factory(customer, worker, price)
        body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash"}))
        payment = Payment.objects.get(pk=body["id"])
        assert api.post(JC_CB, jazzcash_callback(payment), format="multipart").status_code == 200
        return booking

    return _make


def wallet(worker):
    return data(client_for(worker.user).get(WALLET))


def error(resp):
    return resp.json()["error"]


class TestBalance:
    def test_nets_online_earnings_against_cash_commission(self, worker, paid_cash, paid_online):
        assert wallet(worker)["balance"] == "0.00"
        paid_online("2000")  # KaamNow owes 1800
        paid_cash("1000")  # worker owes 100
        w = wallet(worker)
        assert (w["earnings_held"], w["commission_owed"], w["balance"]) == ("1800.00", "100.00", "1700.00")
        assert w["can_request_payout"] is True and w["must_pay_commission"] is False

    def test_unconfirmed_cash_is_not_counted(self, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker, "2000")
        assert Commission.objects.get(booking=booking).status == "pending"
        client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"})  # worker has not confirmed
        assert wallet(worker)["commission_owed"] == "0.00"

    def test_only_workers(self, customer):
        assert client_for(customer).get(WALLET).status_code == 403


class TestPayout:
    def test_request_admin_pays_and_everything_settles(self, worker, admin_user, paid_cash, paid_online):
        online, cash = paid_online("2000"), paid_cash("1000")
        resp = client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT)
        assert resp.status_code == 201, resp.json()
        payout = data(resp)
        assert (payout["amount"], payout["earnings_amount"], payout["commission_amount"]) == (
            "1700.00", "1800.00", "100.00")
        assert payout["account_number"] == "03001234567" and payout["status"] == "requested"
        assert sorted(payout["bookings"]) == sorted([online.pk, cash.pk])
        # Locked: the wallet no longer counts these jobs, and a second request is refused.
        w = wallet(worker)
        assert w["balance"] == "0.00" and w["open_settlement"]["id"] == payout["id"]
        assert client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT).status_code in (400, 409)

        admin = client_for(admin_user)
        open_list = data(admin.get(ADMIN_SETTLEMENTS, {"kind": "payout", "status": "requested"}))["results"]
        assert [s["id"] for s in open_list] == [payout["id"]]
        resp = admin.post(f"{ADMIN_SETTLEMENTS}{payout['id']}/mark-paid/", {"reference": "JC-778899"})
        assert resp.status_code == 200
        assert data(resp)["status"] == "completed"

        assert Commission.objects.get(booking=cash).status == "collected"
        ledger = {e.entry_type: e.amount for e in LedgerEntry.objects.filter(settlement_id=payout["id"])}
        assert ledger == {"worker_payout": Decimal("1700.00"), "commission_settlement": Decimal("100.00")}
        log = AuditLog.objects.get(action="payout_paid")
        assert log.metadata["reference"] == "JC-778899" and log.actor == admin_user
        assert Notification.objects.filter(user=worker.user, title="Payout sent").exists()
        # Paid twice? No.
        assert admin.post(f"{ADMIN_SETTLEMENTS}{payout['id']}/mark-paid/", {"reference": "x"}).status_code == 409
        # New jobs start a fresh balance.
        paid_online("1000")
        assert wallet(worker)["balance"] == "900.00"

    def test_minimum_payout(self, worker, paid_online):
        paid_online("400")  # 360 held, below the Rs 500 minimum
        resp = client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT)
        assert resp.status_code == 400 and "500" in error(resp)["message"]
        assert wallet(worker)["can_request_payout"] is False

    def test_reject_returns_the_balance(self, worker, admin_user, paid_online):
        paid_online("2000")
        payout = data(client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT))
        resp = client_for(admin_user).post(f"{ADMIN_SETTLEMENTS}{payout['id']}/reject/",
                                           {"reason": "Account title does not match the CNIC."})
        assert resp.status_code == 200 and data(resp)["status"] == "rejected"
        assert wallet(worker)["balance"] == "1800.00"
        assert AuditLog.objects.get(action="payout_rejected").metadata["reason"].startswith("Account title")
        assert not LedgerEntry.objects.filter(settlement_id=payout["id"]).exists()

    def test_worker_can_cancel_but_not_someone_elses(self, worker, make_worker, paid_online):
        paid_online("2000")
        payout = data(client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT))
        other = make_worker()
        assert client_for(other.user).post(f"{PAYOUTS}{payout['id']}/cancel/").status_code == 404
        assert client_for(worker.user).post(f"{PAYOUTS}{payout['id']}/cancel/").status_code == 200
        assert wallet(worker)["balance"] == "1800.00"
        assert wallet(worker)["last_payout_account"]["account_number"] == "03001234567"

    def test_only_admins_mark_paid(self, worker, paid_online):
        paid_online("2000")
        payout = data(client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT))
        assert client_for(worker.user).post(f"{ADMIN_SETTLEMENTS}{payout['id']}/mark-paid/",
                                            {"reference": "x"}).status_code == 403

    def test_unverified_worker(self, make_worker):
        unverified = make_worker(verified=False)
        assert client_for(unverified.user).post(PAYOUTS, JAZZCASH_ACCOUNT).status_code == 403

    @pytest.mark.parametrize("payload", [
        {"method": "jazzcash", "account_title": "Ali", "account_number": "12345"},
        {"method": "bank", "account_title": "Ali", "account_number": "03001234567"},
        {"method": "cash", "account_title": "Ali", "account_number": "03001234567"},
    ])
    def test_account_validation(self, worker, paid_online, payload):
        paid_online("2000")
        assert client_for(worker.user).post(PAYOUTS, payload).status_code == 400
        assert not WorkerSettlement.objects.exists()

    def test_bank_iban(self, worker, paid_online):
        paid_online("2000")
        payload = {"method": "bank", "account_title": "Ali Raza", "account_number": "pk36 scbl 0000 0011 2345 6702"}
        resp = client_for(worker.user).post(PAYOUTS, payload)
        assert resp.status_code == 201
        assert data(resp)["account_number"] == "PK36SCBL0000001123456702"

    def test_account_number_is_private(self, worker, customer, paid_online):
        paid_online("2000")
        client_for(worker.user).post(PAYOUTS, JAZZCASH_ACCOUNT)
        assert "03001234567" not in client_for(customer).get(PAY).content.decode()


class TestCommissionOwed:
    def test_worker_pays_online(self, api, worker, paid_cash, gateways):
        cash = paid_cash("3000")  # owes 300
        w = wallet(worker)
        assert w["balance"] == "-300.00" and w["must_pay_commission"] is True
        resp = client_for(worker.user).post(PAY_COMMISSION, {"method": "jazzcash", "amount": "1"})
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["payment"]["amount"] == "300.00" and body["payment"]["purpose"] == "commission"
        assert body["payment"]["checkout"]["fields"]["pp_Amount"] == "30000"
        payment = Payment.objects.get(pk=body["payment"]["id"])
        # Nothing is settled from the app's word, only from the verified callback.
        assert Commission.objects.get(booking=cash).status == "pending"
        assert api.post(JC_CB, jazzcash_callback(payment), format="multipart").status_code == 200
        assert Commission.objects.get(booking=cash).status == "collected"
        settlement = WorkerSettlement.objects.get(pk=body["settlement"]["id"])
        assert settlement.status == "completed"
        assert LedgerEntry.objects.get(settlement=settlement).amount == Decimal("300.00")
        assert wallet(worker)["balance"] == "0.00"

    def test_failed_payment_releases(self, api, worker, paid_cash, gateways):
        paid_cash("3000")
        body = data(client_for(worker.user).post(PAY_COMMISSION, {"method": "jazzcash"}))
        payment = Payment.objects.get(pk=body["payment"]["id"])
        api.post(JC_CB, jazzcash_callback(payment, code="999"), format="multipart")
        assert WorkerSettlement.objects.get(pk=body["settlement"]["id"]).status == "failed"
        assert wallet(worker)["balance"] == "-300.00"
        assert wallet(worker)["open_settlement"] is None

    def test_expired_payment_releases(self, worker, paid_cash, gateways):
        paid_cash("3000")
        body = data(client_for(worker.user).post(PAY_COMMISSION, {"method": "jazzcash"}))
        Payment.objects.filter(pk=body["payment"]["id"]).update(expires_at=timezone.now() - timedelta(minutes=1))
        assert expire_stale_online_payments() == 1
        assert wallet(worker)["balance"] == "-300.00"

    def test_nothing_to_pay(self, worker, paid_online, gateways):
        paid_online("2000")
        assert client_for(worker.user).post(PAY_COMMISSION, {"method": "jazzcash"}).status_code == 400

    def test_admin_records_cash_handed_over(self, worker, admin_user, paid_cash):
        cash = paid_cash("3000")
        resp = client_for(admin_user).post(f"/api/v1/admin/workers/{worker.pk}/record-commission/",
                                           {"method": "cash", "reference": "Receipt 0042"})
        assert resp.status_code == 201
        assert data(resp)["amount"] == "300.00"
        assert Commission.objects.get(booking=cash).status == "collected"
        assert AuditLog.objects.get(action="commission_collected").metadata["reference"] == "Receipt 0042"
        assert wallet(worker)["balance"] == "0.00"
        again = client_for(admin_user).post(f"/api/v1/admin/workers/{worker.pk}/record-commission/",
                                            {"method": "cash", "reference": "x"})
        assert again.status_code == 400

    def test_debt_over_the_limit_blocks_offers(self, worker, make_customer, make_request, paid_cash, admin_user):
        PlatformSettings.objects.filter(pk=PlatformSettings.load().pk).update(commission_debt_limit=Decimal("250"))
        paid_cash("3000")  # owes 300 > 250
        assert wallet(worker)["offers_blocked"] is True
        req = make_request(make_customer())
        payload = {"price": "1500", "estimated_arrival_minutes": 30}
        resp = client_for(worker.user).post(f"/api/v1/requests/{req.pk}/offers/", payload, format="json")
        assert resp.status_code == 403
        assert error(resp)["code"] == "commission_due" and "300" in error(resp)["message"]
        client_for(admin_user).post(f"/api/v1/admin/workers/{worker.pk}/record-commission/",
                                    {"method": "bank", "reference": "IBFT 1"})
        resp = client_for(worker.user).post(f"/api/v1/requests/{req.pk}/offers/", payload, format="json")
        assert resp.status_code == 201

    def test_admin_settings_and_balances_list(self, worker, admin_user, paid_cash):
        admin = client_for(admin_user)
        resp = admin.patch("/api/v1/admin/settings/", {"min_payout": "1000", "commission_debt_limit": "0"},
                           format="json")
        assert resp.status_code == 200
        assert data(resp)["min_payout"] == "1000.00"
        paid_cash("3000")
        assert wallet(worker)["offers_blocked"] is False  # 0 = no limit
        rows = data(admin.get("/api/v1/admin/worker-balances/", {"owing": "true"}))
        assert rows == [{"worker": worker.pk, "worker_name": worker.user.full_name, "worker_phone": worker.user.phone,
                         "earnings_held": "0.00", "commission_owed": "300.00", "balance": "-300.00"}]
        assert data(admin.get("/api/v1/admin/worker-balances/", {"owing": "false"})) == []
        assert client_for(worker.user).get("/api/v1/admin/worker-balances/").status_code == 403
