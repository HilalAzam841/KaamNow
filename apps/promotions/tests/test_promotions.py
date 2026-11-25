"""Promo codes, customer credit and invite rewards."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing.models import Commission, LedgerEntry, Payment, PlatformSettings, WorkerAdjustment
from apps.dashboard.models import AuditLog
from apps.notifications.models import Notification
from apps.promotions.models import CreditEntry, PromoCode, PromoRedemption, Referral, ReferralCode
from conftest import client_for, data, jazzcash_callback, next_phone

pytestmark = pytest.mark.django_db

PAY = "/api/v1/payments/"
CHECK = "/api/v1/promos/check/"
ME = "/api/v1/referrals/me/"
REGISTER = "/api/v1/auth/register/"
WALLET = "/api/v1/payments/wallet/"
ADMIN_PROMOS = "/api/v1/admin/promo-codes/"
JC_CB = "/api/v1/payments/callbacks/jazzcash/"


def promo(code="EID20", **kw):
    fields = {"kind": "percent", "value": Decimal("20"), "max_discount": Decimal("300"), **kw}
    return PromoCode.objects.create(code=code, **fields)


def error(resp):
    return resp.json()["error"]


@pytest.fixture
def booking(customer, worker, completed_booking_factory):
    return completed_booking_factory(customer, worker, "2000")


class TestCheck:
    def test_percent_code_with_cap(self, customer, booking):
        promo()
        q = data(client_for(customer).post(CHECK, {"booking": booking.pk, "promo_code": " eid20 "}))
        assert (q["total"], q["promo_discount"], q["amount"], q["promo_code"]) == (
            "2000.00", "300.00", "1700.00", "EID20")

    def test_reasons_a_code_does_not_work(self, customer, booking, other_category):
        cases = [
            (promo("OLD", ends_at=timezone.now() - timedelta(days=1)), "expired"),
            (promo("OFF", is_active=False), "not active"),
            (promo("BIG", min_order=Decimal("5000")), "at least"),
            (promo("ONLYAC", category=other_category), "only"),
        ]
        for p, words in cases:
            resp = client_for(customer).post(CHECK, {"booking": booking.pk, "promo_code": p.code})
            assert resp.status_code == 400, p.code
            assert error(resp)["code"] == "promo_invalid" and words in error(resp)["message"]
        resp = client_for(customer).post(CHECK, {"booking": booking.pk, "promo_code": "NOPE"})
        assert error(resp)["code"] == "promo_invalid"

    def test_only_own_booking(self, make_customer, booking):
        promo()
        other = make_customer()
        assert client_for(other).post(CHECK, {"booking": booking.pk, "promo_code": "EID20"}).status_code == 403

    def test_discount_never_more_than_the_cap(self, customer, booking):
        promo("HALF", kind="fixed", value=Decimal("1500"))
        CreditEntry.objects.create(user=customer, amount=Decimal("800"), kind="admin")
        q = data(client_for(customer).post(CHECK, {"booking": booking.pk, "promo_code": "HALF", "use_credit": True}))
        # 50% of 2000 at most: the code takes 1000, no room left for credit.
        assert (q["promo_discount"], q["credit_used"], q["amount"]) == ("1000.00", "0.00", "1000.00")


class TestPaying:
    def test_cash_payment_with_code_keeps_worker_earning(self, customer, worker, booking):
        promo("FLAT150", kind="fixed", value=Decimal("150"), max_discount=None)
        pay = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash", "promo_code": "FLAT150"}))
        assert (pay["amount"], pay["discount_amount"]) == ("1850.00", "150.00")
        red = PromoRedemption.objects.get()
        assert red.status == "pending"
        client_for(worker.user).post(f"{PAY}{pay['id']}/confirm/")
        red.refresh_from_db()
        assert red.status == "applied"
        commission = Commission.objects.get(booking=booking)
        assert (commission.worker_earning, commission.discount_amount) == (Decimal("1800.00"), Decimal("150.00"))
        # The worker got 1850 cash and owes 200 commission minus the 150 KaamNow gave away.
        assert data(client_for(worker.user).get(WALLET))["commission_owed"] == "50.00"
        assert LedgerEntry.objects.get(payment_id=pay["id"], entry_type="promo_discount").amount == Decimal("150.00")

    def test_online_payment_with_credit(self, api, customer, worker, booking, gateways):
        CreditEntry.objects.create(user=customer, amount=Decimal("100"), kind="admin")
        body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash", "use_credit": True}))
        assert body["amount"] == "1900.00"
        assert CreditEntry.balance(customer) == Decimal("0.00")
        payment = Payment.objects.get(pk=body["id"])
        assert api.post(JC_CB, jazzcash_callback(payment), format="multipart").status_code == 200
        payment.refresh_from_db()
        assert payment.status == "completed"
        # KaamNow received 1900 and still owes the worker the full 1800.
        assert data(client_for(worker.user).get(WALLET))["earnings_held"] == "1800.00"
        assert CreditEntry.balance(customer) == Decimal("0.00")

    def test_failed_payment_gives_back_code_and_credit(self, api, customer, booking, gateways):
        promo(max_uses=1)
        CreditEntry.objects.create(user=customer, amount=Decimal("100"), kind="admin")
        body = data(client_for(customer).post(
            PAY, {"booking": booking.pk, "method": "jazzcash", "promo_code": "EID20", "use_credit": True}))
        assert body["amount"] == "1600.00"
        payment = Payment.objects.get(pk=body["id"])
        api.post(JC_CB, jazzcash_callback(payment, code="999"), format="multipart")
        assert PromoRedemption.objects.get().status == "released"
        assert CreditEntry.balance(customer) == Decimal("100.00")
        # The code can be used again.
        q = data(client_for(customer).post(CHECK, {"booking": booking.pk, "promo_code": "EID20"}))
        assert q["promo_discount"] == "300.00"

    def test_switching_method_releases_the_hold(self, customer, booking, gateways):
        promo()
        client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash", "promo_code": "EID20"})
        resp = client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash", "promo_code": "EID20"})
        assert resp.status_code == 201, resp.json()
        assert list(PromoRedemption.objects.values_list("status", flat=True).order_by("id")) == [
            "released", "pending"]

    def test_expired_checkout_releases(self, customer, booking, gateways):
        from apps.billing.services import expire_stale_online_payments

        promo()
        body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash", "promo_code": "EID20"}))
        Payment.objects.filter(pk=body["id"]).update(expires_at=timezone.now() - timedelta(minutes=1))
        assert expire_stale_online_payments() == 1
        assert PromoRedemption.objects.get().status == "released"

    def test_usage_limits(self, customer, make_customer, worker, completed_booking_factory):
        promo("ONCE", max_uses=1, max_uses_per_user=1)
        b1 = completed_booking_factory(customer, worker, "2000")
        assert client_for(customer).post(PAY, {"booking": b1.pk, "method": "cash", "promo_code": "ONCE"}).status_code == 201
        other = make_customer()
        b2 = completed_booking_factory(other, worker, "2000")
        resp = client_for(other).post(PAY, {"booking": b2.pk, "method": "cash", "promo_code": "ONCE"})
        assert resp.status_code == 400 and "used up" in error(resp)["message"]
        b3 = completed_booking_factory(customer, worker, "2000")
        promo("TWICE", max_uses_per_user=1)
        client_for(customer).post(PAY, {"booking": b3.pk, "method": "cash", "promo_code": "TWICE"})
        b4 = completed_booking_factory(customer, worker, "2000")
        resp = client_for(customer).post(PAY, {"booking": b4.pk, "method": "cash", "promo_code": "TWICE"})
        assert "already used" in error(resp)["message"]

    def test_first_booking_only(self, customer, worker, completed_booking_factory):
        promo("NEW", first_booking_only=True)
        b1 = completed_booking_factory(customer, worker, "2000")
        pay = data(client_for(customer).post(PAY, {"booking": b1.pk, "method": "cash"}))
        client_for(worker.user).post(f"{PAY}{pay['id']}/confirm/")
        b2 = completed_booking_factory(customer, worker, "2000")
        resp = client_for(customer).post(CHECK, {"booking": b2.pk, "promo_code": "NEW"})
        assert "first booking" in error(resp)["message"]

    def test_refund_worker_share_uses_the_full_booking_total(self, customer, worker, admin_user, booking):
        promo("FLAT200", kind="fixed", value=Decimal("200"), max_discount=None)
        pay = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash", "promo_code": "FLAT200"}))
        client_for(worker.user).post(f"{PAY}{pay['id']}/confirm/")
        refund = data(client_for(admin_user).post(f"/api/v1/admin/payments/{pay['id']}/refund/", {
            "amount": "1000", "method": "cash", "reason": "x", "reference": "R1", "charge_worker": True}))
        assert refund["worker_share"] == "900.00"  # 1000 x 1800 / 2000


class TestReferrals:
    def test_invite_flow_rewards_customer_inviter_with_credit(self, customer, worker, completed_booking_factory):
        code = data(client_for(customer).get(ME))["code"]
        assert len(code) == 7
        resp = client_for(None).post(REGISTER, {"phone": next_phone(), "password": "StrongPass123", "full_name": "Sana Iqbal",
                                                "referral_code": code.lower()})
        assert resp.status_code == 201, resp.json()
        from apps.accounts.models import User

        new = User.objects.get(full_name="Sana Iqbal")
        assert CreditEntry.balance(new) == Decimal("100.00")
        assert Referral.objects.get().status == "pending"
        me = data(client_for(customer).get(ME))
        assert (me["invited"], me["rewarded"]) == (1, 0)
        booking = completed_booking_factory(new, worker, "1000")
        pay = data(client_for(new).post(PAY, {"booking": booking.pk, "method": "cash", "use_credit": True}))
        assert pay["amount"] == "900.00"
        client_for(worker.user).post(f"{PAY}{pay['id']}/confirm/")
        referral = Referral.objects.get()
        assert referral.status == "rewarded" and referral.referrer_reward == Decimal("200.00")
        assert CreditEntry.balance(customer) == Decimal("200.00")
        assert Notification.objects.filter(user=customer, title="Invite reward").exists()
        me = data(client_for(customer).get(ME))
        assert (me["rewarded"], me["rewards_earned"], me["credit_balance"]) == (1, "200.00", "200.00")
        assert me["credit_history"][0]["kind"] == "referral"

    def test_worker_inviter_gets_wallet_money(self, worker, make_worker, completed_booking_factory):
        code = ReferralCode.for_user(worker.user).code
        resp = client_for(None).post(REGISTER, {"phone": next_phone(), "password": "StrongPass123", "full_name": "Usman Ali",
                                                "referral_code": code})
        from apps.accounts.models import User

        new = User.objects.get(full_name="Usman Ali")
        assert resp.status_code == 201
        other = make_worker()
        booking = completed_booking_factory(new, other, "1500")
        pay = data(client_for(new).post(PAY, {"booking": booking.pk, "method": "cash"}))
        client_for(other.user).post(f"{PAY}{pay['id']}/confirm/")
        adj = WorkerAdjustment.objects.get(worker=worker)
        assert adj.amount == Decimal("200.00")
        assert data(client_for(worker.user).get(WALLET))["earnings_held"] == "200.00"

    def test_small_first_booking_does_not_reward(self, customer, worker, completed_booking_factory):
        code = ReferralCode.for_user(customer).code
        client_for(None).post(REGISTER, {"phone": next_phone(), "password": "StrongPass123", "full_name": "Hina Noor",
                                         "referral_code": code})
        from apps.accounts.models import User

        new = User.objects.get(full_name="Hina Noor")
        booking = completed_booking_factory(new, worker, "300")
        pay = data(client_for(new).post(PAY, {"booking": booking.pk, "method": "cash"}))
        client_for(worker.user).post(f"{PAY}{pay['id']}/confirm/")
        assert Referral.objects.get().status == "pending"

    def test_bad_code_is_refused_and_no_account_is_made(self):
        resp = client_for(None).post(REGISTER, {"phone": next_phone(), "password": "StrongPass123", "full_name": "Ali Khan",
                                                "referral_code": "ZZZZZZZ"})
        assert resp.status_code == 400
        from apps.accounts.models import User

        assert not User.objects.filter(full_name="Ali Khan").exists()

    def test_settings_change_rewards(self, admin_user, customer):
        resp = client_for(admin_user).patch("/api/v1/admin/settings/", {"referral_welcome_credit": "0",
                                                                        "referral_reward": "300"})
        assert resp.status_code == 200, resp.json()
        cfg = PlatformSettings.load()
        assert (cfg.referral_welcome_credit, cfg.referral_reward) == (Decimal("0.00"), Decimal("300.00"))
        code = ReferralCode.for_user(customer).code
        client_for(None).post(REGISTER, {"phone": next_phone(), "password": "StrongPass123", "full_name": "Zara Ahmed",
                                         "referral_code": code})
        assert not CreditEntry.objects.exists()


class TestAdminPromoCodes:
    def test_create_update_and_stats(self, admin_user, customer, worker, booking):
        resp = client_for(admin_user).post(ADMIN_PROMOS, {
            "code": "ramzan-25", "description": "Ramzan offer", "kind": "percent", "value": "25",
            "max_discount": "400", "max_uses": 100})
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["code"] == "RAMZAN-25" and body["uses"] == 0
        pay = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash", "promo_code": "ramzan-25"}))
        client_for(worker.user).post(f"{PAY}{pay['id']}/confirm/")
        row = data(client_for(admin_user).get(f"{ADMIN_PROMOS}{body['id']}/"))
        assert (row["uses"], row["discount_given"]) == (1, "400.00")
        resp = client_for(admin_user).patch(f"{ADMIN_PROMOS}{body['id']}/", {"is_active": False})
        assert data(resp)["is_active"] is False and data(resp)["uses"] == 1
        assert AuditLog.objects.filter(action="promo_saved").count() == 2

    def test_validation(self, admin_user):
        promo("TAKEN")
        bad = [
            {"code": "taken", "kind": "fixed", "value": "100"},
            {"code": "BIGPCT", "kind": "percent", "value": "150"},
            {"code": "x", "kind": "fixed", "value": "100"},
            {"code": "DATES", "kind": "fixed", "value": "100", "starts_at": "2026-12-10T00:00:00Z",
             "ends_at": "2026-12-01T00:00:00Z"},
        ]
        for body in bad:
            assert client_for(admin_user).post(ADMIN_PROMOS, body).status_code == 400, body

    def test_admin_only_and_no_delete(self, admin_user, customer):
        p = promo()
        assert client_for(customer).get(ADMIN_PROMOS).status_code == 403
        assert client_for(admin_user).delete(f"{ADMIN_PROMOS}{p.pk}/").status_code == 405
