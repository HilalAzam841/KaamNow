from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.billing.models import Commission
from apps.jobs.models import Booking
from conftest import advance_to, client_for, data

pytestmark = pytest.mark.django_db
URL = "/api/v1/bookings/"


def status_url(b):
    return f"{URL}{b.pk}/status/"


class TestBookingAccess:
    def test_participants_see_booking_others_do_not(self, customer, worker, make_booking, make_customer, make_worker):
        booking = make_booking(customer, worker)
        assert data(client_for(customer).get(f"{URL}{booking.pk}/"))["id"] == booking.pk
        assert data(client_for(worker.user).get(f"{URL}{booking.pk}/"))["id"] == booking.pk
        assert client_for(make_customer()).get(f"{URL}{booking.pk}/").status_code == 404
        assert client_for(make_worker().user).get(f"{URL}{booking.pk}/").status_code == 404

    def test_list_scoped(self, customer, worker, make_booking, make_customer):
        make_booking(customer, worker)
        assert data(client_for(customer).get(URL))["count"] == 1
        assert data(client_for(worker.user).get(URL))["count"] == 1
        assert data(client_for(make_customer()).get(URL))["count"] == 0

    def test_contact_details_only_while_active(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        worker_view = data(client_for(worker.user).get(f"{URL}{booking.pk}/"))
        assert worker_view["contact"]["customer_phone"] == customer.phone
        assert worker_view["contact"]["address"]
        customer_view = data(client_for(customer).get(f"{URL}{booking.pk}/"))
        assert customer_view["contact"] == {"worker_phone": worker.user.phone}
        client_for(customer).post(f"{URL}{booking.pk}/cancel/", {"reason": "Plans changed"})
        assert data(client_for(worker.user).get(f"{URL}{booking.pk}/"))["contact"] is None

    def test_otp_never_in_response(self, customer, worker, make_booking):
        booking = advance_to(make_booking(customer, worker), Booking.Status.IN_PROGRESS)
        client_for(customer).post(f"{URL}{booking.pk}/completion-otp/")
        for user in (customer, worker.user):
            raw = client_for(user).get(f"{URL}{booking.pk}/").content.decode()
            assert "otp_hash" not in raw and "completion_otp" not in raw


class TestStatusFlow:
    def test_full_progression(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        w = client_for(worker.user)
        for s in ("on_the_way", "arrived", "in_progress"):
            resp = w.post(status_url(booking), {"status": s})
            assert resp.status_code == 200, resp.json()
            assert data(resp)["status"] == s
        body = data(w.get(f"{URL}{booking.pk}/"))
        assert [h["to_status"] for h in body["status_history"]] == ["confirmed", "on_the_way", "arrived", "in_progress"]
        assert body["on_the_way_at"] and body["arrived_at"] and body["started_at"]

    def test_cannot_skip_steps(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(worker.user).post(status_url(booking), {"status": "in_progress"}).status_code == 409

    def test_cannot_set_completed_via_status(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(worker.user).post(status_url(booking), {"status": "completed"}).status_code == 400

    def test_customer_cannot_update_status(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(customer).post(status_url(booking), {"status": "on_the_way"}).status_code == 403


class TestCancel:
    def test_worker_cancels_before_start(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = client_for(worker.user).post(f"{URL}{booking.pk}/cancel/", {"reason": "Emergency at home"})
        assert data(resp)["status"] == "cancelled"
        booking.request.refresh_from_db()
        assert booking.request.status == "cancelled"

    def test_reason_required(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(customer).post(f"{URL}{booking.pk}/cancel/", {}).status_code == 400

    def test_cannot_cancel_after_work_started(self, customer, worker, make_booking):
        booking = advance_to(make_booking(customer, worker), Booking.Status.IN_PROGRESS)
        assert client_for(customer).post(f"{URL}{booking.pk}/cancel/", {"reason": "x"}).status_code == 409


class TestCompletionOTP:
    def _in_progress(self, customer, worker, make_booking, price="2000"):
        return advance_to(make_booking(customer, worker, price), Booking.Status.IN_PROGRESS)

    def test_customer_gets_otp_and_worker_completes(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        resp = client_for(customer).post(f"{URL}{booking.pk}/completion-otp/")
        assert resp.status_code == 201
        otp = data(resp)["otp"]
        assert len(otp) == 6 and otp.isdigit()
        booking.refresh_from_db()
        assert booking.completion_otp_hash and otp not in booking.completion_otp_hash  # stored hashed

        resp = client_for(worker.user).post(f"{URL}{booking.pk}/complete/", {"otp": otp})
        assert resp.status_code == 200, resp.json()
        body = data(resp)
        assert body["status"] == "completed"
        assert body["completed_via"] == "otp"
        assert body["commission"] == {
            "rate_percent": "10.00", "commission_amount": "200.00", "worker_earning": "1800.00", "status": "pending",
        }
        worker.refresh_from_db()
        assert worker.completed_jobs_count == 1
        assert Commission.objects.get(booking=booking).commission_amount == Decimal("200.00")

    def test_worker_cannot_request_otp(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        assert client_for(worker.user).post(f"{URL}{booking.pk}/completion-otp/").status_code == 403

    def test_otp_only_after_work_started(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert client_for(customer).post(f"{URL}{booking.pk}/completion-otp/").status_code == 409

    def test_resend_cooldown(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        c = client_for(customer)
        assert c.post(f"{URL}{booking.pk}/completion-otp/").status_code == 201
        assert c.post(f"{URL}{booking.pk}/completion-otp/").status_code == 429

    def test_wrong_otp_attempt_limit(self, customer, worker, make_booking, settings):
        booking = self._in_progress(customer, worker, make_booking)
        otp = data(client_for(customer).post(f"{URL}{booking.pk}/completion-otp/"))["otp"]
        wrong = "000000" if otp != "000000" else "111111"
        w = client_for(worker.user)
        for _ in range(settings.KAAMNOW["OTP_MAX_ATTEMPTS"]):
            resp = w.post(f"{URL}{booking.pk}/complete/", {"otp": wrong})
            assert resp.status_code == 400
            assert resp.json()["error"]["code"] == "invalid_otp"
        booking.refresh_from_db()
        assert booking.completion_otp_attempts == settings.KAAMNOW["OTP_MAX_ATTEMPTS"]
        # Even the correct code is now refused: it was burned.
        resp = w.post(f"{URL}{booking.pk}/complete/", {"otp": otp})
        assert resp.status_code in (400, 429)
        booking.refresh_from_db()
        assert booking.status == Booking.Status.IN_PROGRESS

    def test_expired_otp(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        otp = data(client_for(customer).post(f"{URL}{booking.pk}/completion-otp/"))["otp"]
        Booking.objects.filter(pk=booking.pk).update(completion_otp_expires_at=timezone.now() - timedelta(seconds=1))
        resp = client_for(worker.user).post(f"{URL}{booking.pk}/complete/", {"otp": otp})
        assert resp.status_code == 400
        assert "expired" in resp.json()["error"]["message"]

    def test_new_otp_invalidates_old(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        c = client_for(customer)
        old = data(c.post(f"{URL}{booking.pk}/completion-otp/"))["otp"]
        Booking.objects.filter(pk=booking.pk).update(completion_otp_sent_at=timezone.now() - timedelta(minutes=5))
        new = data(c.post(f"{URL}{booking.pk}/completion-otp/"))["otp"]
        if old != new:
            assert client_for(worker.user).post(f"{URL}{booking.pk}/complete/", {"otp": old}).status_code == 400
        assert client_for(worker.user).post(f"{URL}{booking.pk}/complete/", {"otp": new}).status_code == 200

    def test_no_otp_issued(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        assert client_for(worker.user).post(f"{URL}{booking.pk}/complete/", {"otp": "123456"}).status_code == 400

    def test_customer_confirms_in_app(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        c = client_for(customer)
        assert c.post(f"{URL}{booking.pk}/complete/", {}).status_code == 400
        resp = c.post(f"{URL}{booking.pk}/complete/", {"confirm": True})
        assert data(resp)["completed_via"] == "customer_confirmation"
        assert data(resp)["commission"] is None  # customers don't see commission split

    def test_otp_endpoint_rate_limited(self, customer, worker, make_booking, monkeypatch):
        from rest_framework.throttling import SimpleRateThrottle

        monkeypatch.setitem(SimpleRateThrottle.THROTTLE_RATES, "otp", "3/min")
        booking = self._in_progress(customer, worker, make_booking)
        w = client_for(worker.user)
        codes = [w.post(f"{URL}{booking.pk}/complete/", {"otp": "123456"}).status_code for _ in range(4)]
        assert codes[-1] == 429

    def test_cannot_complete_twice(self, customer, worker, make_booking):
        booking = self._in_progress(customer, worker, make_booking)
        c = client_for(customer)
        c.post(f"{URL}{booking.pk}/complete/", {"confirm": True})
        assert c.post(f"{URL}{booking.pk}/complete/", {"confirm": True}).status_code == 409
        assert Commission.objects.filter(booking=booking).count() == 1
