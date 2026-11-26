from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing.models import LedgerEntry, Payment, PlatformSettings, WorkerAdjustment
from apps.billing import wallet
from apps.cancellations.models import CancellationFee
from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from conftest import advance_to, client_for, data, jazzcash_callback, request_payload

JC_CB = "/api/v1/payments/callbacks/jazzcash/"


def shape(booking, *, booked_ago=60, starts_in=None):
    """Sets when the booking was made (minutes ago) and when the job starts (minutes from now)."""
    now = timezone.now()
    Booking.objects.filter(pk=booking.pk).update(created_at=now - timedelta(minutes=booked_ago))
    if starts_in is not None:
        booking.request.__class__.objects.filter(pk=booking.request_id).update(
            preferred_time=now + timedelta(minutes=starts_in))
    booking.refresh_from_db()
    booking.request.refresh_from_db()
    return booking


def quote(user, booking):
    return data(client_for(user).get(f"/api/v1/bookings/{booking.pk}/cancel-fee/"))


def cancel(user, booking, reason="Plans changed"):
    return client_for(user).post(f"/api/v1/bookings/{booking.pk}/cancel/", {"reason": reason})


@pytest.mark.django_db
class TestQuote:
    def test_free_well_before_the_window_with_the_time_it_ends(self, customer, worker, make_booking):
        b = shape(make_booking(customer, worker), starts_in=300)
        q = quote(customer, b)
        assert q["fee"] == "0.00" and q["reason"] is None
        assert q["fee_after"] == "200.00"
        free_until = timezone.datetime.fromisoformat(q["free_until"])
        assert abs((free_until - (b.request.preferred_time - timedelta(minutes=120))).total_seconds()) < 1

    def test_late_inside_the_window(self, customer, worker, make_booking):
        b = shape(make_booking(customer, worker), starts_in=60)
        q = quote(customer, b)
        assert q["fee"] == "200.00" and q["reason"] == "late" and q["free_until"] is None

    def test_just_booked_is_free_even_inside_the_window(self, customer, worker, make_booking):
        b = shape(make_booking(customer, worker), booked_ago=2, starts_in=60)
        q = quote(customer, b)
        assert q["fee"] == "0.00" and q["fee_after"] == "200.00" and q["free_until"]

    def test_worker_on_the_way_or_arrived(self, customer, worker, make_booking):
        b = advance_to(shape(make_booking(customer, worker), starts_in=300), Booking.Status.ON_THE_WAY)
        q = quote(customer, b)
        assert q["fee"] == "300.00" and q["reason"] == "on_the_way"
        from apps.jobs.services import update_booking_status

        b = update_booking_status(b, worker.user, Booking.Status.ARRIVED)
        assert quote(customer, b)["reason"] == "arrived"

    def test_free_when_the_worker_is_late(self, customer, worker, make_booking):
        b = shape(make_booking(customer, worker), starts_in=-20)
        assert quote(customer, b)["fee"] == "0.00"

    def test_workers_never_pay_and_switching_off_or_capping(self, customer, worker, make_booking):
        b = shape(make_booking(customer, worker, price="150"), starts_in=60)
        assert quote(worker.user, b)["fee"] == "0.00"
        assert quote(customer, b)["fee"] == "150.00", "never more than the job price"
        cfg = PlatformSettings.load()
        cfg.cancellation_fee_enabled = False
        cfg.save()
        assert quote(customer, b)["fee"] == "0.00"

    def test_others_cannot_see_the_quote(self, customer, make_customer, worker, make_booking):
        b = make_booking(customer, worker)
        assert client_for(make_customer()).get(f"/api/v1/bookings/{b.pk}/cancel-fee/").status_code == 404


@pytest.mark.django_db
class TestCharge:
    def test_late_customer_cancel_charges_and_tells_both(self, customer, worker, make_booking):
        b = shape(make_booking(customer, worker), starts_in=60)
        resp = cancel(customer, b)
        assert resp.status_code == 200
        body = data(resp)
        assert body["status"] == "cancelled"
        fee = CancellationFee.objects.get()
        assert body["cancellation_fee"] == {"id": fee.pk, "amount": "200.00", "worker_share": "180.00",
                                            "status": "owed", "reason": "late"}
        assert fee.commission_percent == Decimal("10.00")
        assert Notification.objects.filter(user=customer, title="Late cancellation fee").exists()
        assert Notification.objects.filter(user=worker.user, title="Cancellation fee for you").exists()

    def test_free_cancel_and_worker_cancel_charge_nothing(self, customer, worker, make_booking):
        early = shape(make_booking(customer, worker), starts_in=600)
        assert data(cancel(customer, early))["cancellation_fee"] is None
        late = shape(make_booking(customer, worker), starts_in=30)
        assert cancel(worker.user, late).status_code == 200
        assert not CancellationFee.objects.exists()


@pytest.fixture
def owed(customer, worker, make_booking):
    b = shape(make_booking(customer, worker), starts_in=60)
    cancel(customer, b)
    return CancellationFee.objects.get()


@pytest.mark.django_db
class TestBlockAndPay:
    def test_unpaid_fee_blocks_new_jobs_only_when_online_payment_works(self, customer, category, owed, settings):
        c = client_for(customer)
        settings.PAYMENT_GATEWAYS = {}
        assert c.post("/api/v1/requests/", request_payload(category)).status_code == 201
        from conftest import JAZZCASH_TEST_CONFIG

        settings.PAYMENT_GATEWAYS = {"jazzcash": dict(JAZZCASH_TEST_CONFIG)}
        resp = c.post("/api/v1/requests/", request_payload(category))
        assert resp.status_code == 402
        assert resp.json()["error"]["code"] == "cancellation_fee_unpaid"
        assert "Rs. 200" in resp.json()["error"]["message"]

    def test_unpaid_fee_blocks_package_booking(self, customer, worker, category, owed, gateways):
        from apps.packages.models import ServicePackage

        pkg = ServicePackage.objects.create(worker=worker, category=category, title="AC service",
                                            price=Decimal("2500"), duration_minutes=60)
        when = (timezone.now() + timedelta(hours=8)).replace(minute=0, second=0, microsecond=0)
        resp = client_for(customer).post(f"/api/v1/packages/{pkg.pk}/book/", {
            "preferred_time": when.isoformat(), "latitude": "31.510000", "longitude": "74.344000",
            "address": "House 12, Street 4, Gulberg III"})
        assert resp.status_code == 402

    def test_pay_online_credits_the_worker(self, api, customer, worker, category, owed, gateways):
        c = client_for(customer)
        assert data(c.get("/api/v1/cancellation-fees/"))["results"][0]["status"] == "owed"
        assert c.post(f"/api/v1/cancellation-fees/{owed.pk}/pay/", {"method": "cash"}).status_code == 400
        resp = c.post(f"/api/v1/cancellation-fees/{owed.pk}/pay/", {"method": "jazzcash"})
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["amount"] == "200.00" and body["checkout"]["method"] == "POST"
        payment = Payment.objects.get(pk=body["id"])
        assert payment.purpose == "cancellation_fee" and payment.status == "pending"
        # A second attempt replaces the first.
        second = data(c.post(f"/api/v1/cancellation-fees/{owed.pk}/pay/", {"method": "jazzcash"}))
        payment.refresh_from_db()
        assert payment.status == "failed"
        payment = Payment.objects.get(pk=second["id"])

        assert api.post(JC_CB, jazzcash_callback(payment), format="multipart").status_code == 200
        owed.refresh_from_db()
        assert owed.status == "paid" and owed.payment == payment
        adj = WorkerAdjustment.objects.get(worker=worker)
        assert adj.amount == Decimal("180.00")
        assert wallet.summary(worker)["balance"] == Decimal("180.00")
        entries = {e.entry_type: e.amount for e in LedgerEntry.objects.filter(payment=payment)}
        assert entries == {"cancellation_fee": Decimal("200.00"), "platform_commission": Decimal("20.00"),
                           "worker_earning": Decimal("180.00")}
        assert Notification.objects.filter(user=worker.user, title="Cancellation fee received").exists()
        # Paid: new jobs are allowed again, and paying twice is refused.
        assert c.post("/api/v1/requests/", request_payload(category)).status_code == 201
        assert c.post(f"/api/v1/cancellation-fees/{owed.pk}/pay/", {"method": "jazzcash"}).status_code == 409
        # Replaying the callback changes nothing.
        api.post(JC_CB, jazzcash_callback(payment), format="multipart")
        assert WorkerAdjustment.objects.count() == 1

    def test_receipt_for_a_paid_fee(self, api, customer, worker, owed, gateways):
        c = client_for(customer)
        payment = Payment.objects.get(pk=data(c.post(f"/api/v1/cancellation-fees/{owed.pk}/pay/",
                                                     {"method": "jazzcash"}))["id"])
        api.post(JC_CB, jazzcash_callback(payment), format="multipart")
        r = data(c.get(f"/api/v1/payments/{payment.pk}/receipt/"))
        assert r["title"] == "Late cancellation fee" and r["booking"] == owed.booking_id
        assert r["total"] == "200.00"
        assert client_for(worker.user).get(f"/api/v1/payments/{payment.pk}/receipt/").status_code == 200

    def test_only_the_customer_pays_and_others_see_nothing(self, customer, make_customer, worker, owed, gateways):
        assert client_for(worker.user).post(f"/api/v1/cancellation-fees/{owed.pk}/pay/",
                                            {"method": "jazzcash"}).status_code == 403
        worker_view = data(client_for(worker.user).get("/api/v1/cancellation-fees/"))["results"]
        assert [f["id"] for f in worker_view] == [owed.pk]
        stranger = client_for(make_customer())
        assert data(stranger.get("/api/v1/cancellation-fees/"))["count"] == 0
        assert stranger.post(f"/api/v1/cancellation-fees/{owed.pk}/pay/", {"method": "jazzcash"}).status_code == 404


@pytest.mark.django_db
class TestAdmin:
    def test_waive_is_audited_and_unblocks(self, admin_user, customer, category, owed, gateways):
        c = client_for(admin_user)
        assert data(c.get("/api/v1/admin/cancellation-fees/?status=owed"))["count"] == 1
        resp = c.post(f"/api/v1/admin/cancellation-fees/{owed.pk}/waive/", {"reason": "Worker agreed"})
        assert resp.status_code == 200 and data(resp)["status"] == "waived"
        assert AuditLog.objects.filter(action="cancellation_fee_settled").count() == 1
        assert Notification.objects.filter(user=customer, title="Fee waived").exists()
        assert client_for(customer).post("/api/v1/requests/", request_payload(category)).status_code == 201
        assert c.post(f"/api/v1/admin/cancellation-fees/{owed.pk}/waive/", {"reason": "again"}).status_code == 409

    def test_record_received_pays_the_worker(self, admin_user, worker, owed):
        resp = client_for(admin_user).post(f"/api/v1/admin/cancellation-fees/{owed.pk}/record-received/",
                                           {"reference": "Office receipt 42"})
        assert resp.status_code == 200 and data(resp)["status"] == "paid"
        payment = Payment.objects.get(purpose="cancellation_fee")
        assert payment.status == "completed" and payment.confirmed_by == admin_user
        assert wallet.summary(worker)["balance"] == Decimal("180.00")
        assert AuditLog.objects.get(action="cancellation_fee_settled").metadata["outcome"] == "received"

    def test_only_admins(self, customer, owed):
        c = client_for(customer)
        assert c.get("/api/v1/admin/cancellation-fees/").status_code == 403
        assert c.post(f"/api/v1/admin/cancellation-fees/{owed.pk}/waive/", {"reason": "please"}).status_code == 403

    def test_settings_can_be_changed(self, admin_user, customer, worker, make_booking):
        c = client_for(admin_user)
        resp = c.patch("/api/v1/admin/settings/", {"late_cancellation_fee": "250", "cancellation_window_minutes": 180})
        assert resp.status_code == 200
        b = shape(make_booking(customer, worker), starts_in=150)
        assert quote(customer, b)["fee"] == "250.00"
        cfg = data(client_for(customer).get("/api/v1/app/config/"))["cancellation"]
        assert cfg == {"enabled": True, "free_minutes": 5, "window_minutes": 180, "late_fee": "250.00",
                       "on_the_way_fee": "300.00"}
