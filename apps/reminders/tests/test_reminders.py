from datetime import timedelta
from unittest import mock

import pytest
from django.utils import timezone

from apps.billing.models import PlatformSettings
from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking, ServiceRequest
from apps.notifications.models import Notification
from apps.reminders import services
from apps.reminders.models import BookingReminder, NoShowReport
from apps.reminders.tasks import send_booking_reminders
from conftest import advance_to, client_for, data


def booked(make_request, make_offer, customer, worker, start, created_ago=timedelta(days=2), emergency=False):
    from apps.offers.services import accept_offer

    req = make_request(customer, preferred_time=start)
    if emergency:
        ServiceRequest.objects.filter(pk=req.pk).update(is_emergency=True)
        req.refresh_from_db()
    booking = accept_offer(make_offer(worker, req), customer)
    Booking.objects.filter(pk=booking.pk).update(created_at=timezone.now() - created_ago)
    booking.refresh_from_db()
    return booking


def reminders_for(user):
    return list(Notification.objects.filter(user=user, type=Notification.Type.REMINDER))


@pytest.mark.django_db
class TestReminders:
    def test_day_and_hour_reminders_go_to_both_once(self, customer, worker, make_request, make_offer):
        b = booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(hours=20))
        assert services.send_due_reminders() == 1
        assert services.send_due_reminders() == 0  # idempotent
        assert len(reminders_for(customer)) == 1 and len(reminders_for(worker.user)) == 1
        assert reminders_for(customer)[0].data == {"booking_id": b.pk, "reminder": "day"}
        assert worker.user.full_name in reminders_for(customer)[0].body
        # The worker's reminder points to the booking but does not repeat the private address.
        assert b.request.address not in reminders_for(worker.user)[0].body
        # 40 minutes before the start, the hour reminder follows.
        later = b.request.preferred_time - timedelta(minutes=40)
        assert services.send_due_reminders(now=later) == 1
        assert set(BookingReminder.objects.filter(booking=b).values_list("kind", flat=True)) == {"day", "hour"}
        assert len(reminders_for(customer)) == 2

    def test_not_yet_due_and_far_jobs(self, customer, worker, make_request, make_offer):
        booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(hours=30))
        assert services.send_due_reminders() == 0

    def test_close_jobs_get_only_the_hour_reminder(self, customer, worker, make_request, make_offer):
        b = booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(hours=2))
        assert services.send_due_reminders() == 0  # inside 3 hours: no day reminder
        assert services.send_due_reminders(now=b.request.preferred_time - timedelta(minutes=30)) == 1
        assert list(BookingReminder.objects.values_list("kind", flat=True)) == ["hour"]

    def test_just_booked_emergency_cancelled_and_started_are_skipped(self, customer, make_worker, make_request,
                                                                     make_offer):
        soon = timezone.now() + timedelta(minutes=50)
        booked(make_request, make_offer, customer, make_worker(), soon, created_ago=timedelta(minutes=5))
        booked(make_request, make_offer, customer, make_worker(), soon + timedelta(minutes=1), emergency=True)
        started = booked(make_request, make_offer, customer, make_worker(), soon + timedelta(minutes=2))
        advance_to(started, Booking.Status.ON_THE_WAY)
        assert services.send_due_reminders() == 0

    def test_users_can_turn_reminders_off(self, customer, worker, make_request, make_offer):
        resp = client_for(customer).patch("/api/v1/auth/me/", {"booking_reminders": False}, format="json")
        assert resp.status_code == 200 and data(resp)["booking_reminders"] is False
        booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(minutes=50))
        assert send_booking_reminders() == 1
        assert reminders_for(customer) == [] and len(reminders_for(worker.user)) == 1

    def test_reminders_follow_each_users_language(self, customer, worker, make_request, make_offer):
        customer.language = "ur"
        customer.save()
        booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(minutes=50))
        services.send_due_reminders()
        assert reminders_for(worker.user)[0].title.startswith("Your ")
        assert not reminders_for(customer)[0].title.startswith("Your ")

    def test_sms_only_when_switched_on(self, settings, customer, worker, make_request, make_offer):
        settings.SMS_BACKEND = "console"
        settings.DEBUG = True
        b = booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(minutes=50))
        with mock.patch("apps.common.sms.send") as send:
            services.send_due_reminders()
        send.assert_not_called()
        PlatformSettings.objects.filter(pk=1).update(reminder_sms_enabled=True)
        b2 = booked(make_request, make_offer, customer, worker, b.request.preferred_time + timedelta(hours=3))
        with mock.patch("apps.common.sms.send") as send:
            services.send_due_reminders(now=b2.request.preferred_time - timedelta(minutes=30))
        assert sorted(c.args[0] for c in send.call_args_list) == sorted([customer.phone, worker.user.phone])
        assert BookingReminder.objects.get(booking=b2, kind="hour").sms_sent is True

    def test_sms_failure_does_not_stop_reminders(self, settings, customer, worker, make_request, make_offer):
        from apps.common.sms import SmsError

        settings.DEBUG = True
        PlatformSettings.objects.filter(pk=1).update(reminder_sms_enabled=True)
        booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(minutes=50))
        with mock.patch("apps.common.sms.send", side_effect=SmsError("down")):
            assert services.send_due_reminders() == 1
        assert len(reminders_for(customer)) == 1

    def test_beat_schedule_has_the_task(self, settings):
        assert settings.CELERY_BEAT_SCHEDULE["send-booking-reminders"]["task"] == \
            "apps.reminders.tasks.send_booking_reminders"


def no_show_url(b):
    return f"/api/v1/bookings/{b.pk}/no-show/"


@pytest.mark.django_db
class TestNoShows:
    def test_customer_reports_worker_after_grace(self, customer, worker, make_request, make_offer, admin_user):
        start = timezone.now() + timedelta(hours=5)
        b = booked(make_request, make_offer, customer, worker, start)
        c = client_for(customer)
        info = data(c.get(f"/api/v1/bookings/{b.pk}/"))["no_show"]
        assert info["you_can_report"] == "worker" and info["reported"] is None
        resp = c.post(no_show_url(b), {"note": "Waited an hour"}, format="json")
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "too_early"
        ServiceRequest.objects.filter(pk=b.request_id).update(preferred_time=timezone.now() - timedelta(minutes=31))
        resp = c.post(no_show_url(b), {"note": "Waited an hour"}, format="json")
        assert resp.status_code == 200, resp.json()
        body = data(resp)
        assert body["status"] == "cancelled" and body["no_show"]["reported"] == "worker"
        report = NoShowReport.objects.get(booking=b)
        assert report.against == worker.user and report.reported_by == customer
        assert Notification.objects.filter(user=admin_user, type=Notification.Type.NO_SHOW).exists()
        assert Notification.objects.filter(user=worker.user, type=Notification.Type.NO_SHOW).exists()
        assert c.post(no_show_url(b), {}, format="json").status_code == 409  # only once

    def test_worker_reports_customer_after_arriving(self, customer, worker, make_request, make_offer):
        b = booked(make_request, make_offer, customer, worker, timezone.now() + timedelta(minutes=10))
        w = client_for(worker.user)
        assert data(w.get(f"/api/v1/bookings/{b.pk}/"))["no_show"]["you_can_report"] is None  # not arrived
        assert w.post(no_show_url(b), {}, format="json").status_code == 409
        b = advance_to(b, Booking.Status.ARRIVED)
        assert w.post(no_show_url(b), {}, format="json").json()["error"]["code"] == "too_early"
        Booking.objects.filter(pk=b.pk).update(arrived_at=timezone.now() - timedelta(minutes=40))
        ServiceRequest.objects.filter(pk=b.request_id).update(preferred_time=timezone.now() - timedelta(minutes=35))
        resp = w.post(no_show_url(b), {}, format="json")
        assert resp.status_code == 200, resp.json()
        assert NoShowReport.objects.get(booking=b).against == customer
        # Once the worker has arrived, the customer can no longer report them absent.
        assert data(client_for(customer).get(f"/api/v1/bookings/{b.pk}/"))["no_show"]["you_can_report"] is None

    def test_outsiders_and_wrong_states(self, customer, worker, make_customer, make_request, make_offer):
        b = booked(make_request, make_offer, customer, worker, timezone.now() - timedelta(hours=1),
                   created_ago=timedelta(days=1))
        assert client_for(make_customer()).post(no_show_url(b), {}, format="json").status_code == 404
        b = advance_to(b, Booking.Status.IN_PROGRESS)
        assert client_for(customer).post(no_show_url(b), {}, format="json").status_code == 409

    def test_admin_lists_and_reviews(self, customer, make_customer, worker, make_request, make_offer, admin_user):
        past = timezone.now() - timedelta(hours=2)
        for who in (customer, make_customer()):
            b = booked(make_request, make_offer, who, worker, past, created_ago=timedelta(days=1))
            services.report_no_show(b, who)
            past -= timedelta(hours=3)
        a = client_for(admin_user)
        rows = data(a.get("/api/v1/admin/no-shows/?side=worker"))["results"]
        assert len(rows) == 2 and rows[0]["against_total"] == 2 and rows[0]["against_role"] == "worker"
        rid = rows[0]["id"]
        resp = a.post(f"/api/v1/admin/no-shows/{rid}/review/", {"review": "dismissed", "note": "Traffic"}, format="json")
        assert resp.status_code == 200 and data(resp)["against_total"] == 1
        assert AuditLog.objects.filter(action=AuditLog.Action.NO_SHOW_REVIEWED).exists()
        assert client_for(customer).get("/api/v1/admin/no-shows/").status_code == 403

    def test_admin_settings_include_reminder_options(self, admin_user):
        a = client_for(admin_user)
        resp = a.patch("/api/v1/admin/settings/", {"reminder_sms_enabled": True, "no_show_grace_minutes": 45},
                       format="json")
        assert resp.status_code == 200, resp.json()
        assert PlatformSettings.load().no_show_grace_minutes == 45
        assert a.patch("/api/v1/admin/settings/", {"no_show_grace_minutes": 5}, format="json").status_code == 400
