from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest
from django.utils import timezone

from apps.jobs.models import ServiceRequest
from apps.notifications.models import Notification
from apps.offers.models import WorkerOffer
from apps.recurring import services
from apps.recurring.models import RecurringJob, RecurringVisit
from apps.recurring.tasks import create_recurring_visits
from apps.scheduling.models import TimeOff
from conftest import client_for, data

URL = "/api/v1/recurring-jobs/"
PKT = ZoneInfo("Asia/Karachi")


def in_days(days, hour=10):
    day = timezone.localdate() + timedelta(days=days)
    return datetime.combine(day, time(hour), tzinfo=PKT)


def repeat(customer, booking, frequency="weekly", first_visit=None):
    return client_for(customer).post(URL + "from-booking/", {
        "booking": booking.pk, "frequency": frequency,
        "first_visit": (first_visit or in_days(7)).isoformat()}, format="json")


@pytest.fixture
def plan(customer, worker, completed_booking_factory, django_capture_on_commit_callbacks):
    booking = completed_booking_factory(customer, worker)
    with django_capture_on_commit_callbacks(execute=True):
        resp = repeat(customer, booking, first_visit=in_days(1, 15))
    assert resp.status_code == 201, resp.json()
    return RecurringJob.objects.get(pk=data(resp)["id"])


@pytest.mark.django_db
class TestCreate:
    def test_repeat_a_finished_job(self, customer, worker, completed_booking_factory,
                                   django_capture_on_commit_callbacks):
        booking = completed_booking_factory(customer, worker)
        with django_capture_on_commit_callbacks(execute=True):
            resp = repeat(customer, booking, "biweekly")
        assert resp.status_code == 201
        body = data(resp)
        assert body["frequency"] == "biweekly" and body["status"] == "active"
        assert body["worker"] == {"id": worker.pk, "full_name": worker.user.full_name}
        assert body["title"] == booking.request.title and body["address"] == booking.request.address
        note = Notification.objects.get(user=worker.user, type=Notification.Type.RECURRING)
        assert note.data == {"recurring_id": body["id"]}
        # Repeating the same booking twice is refused.
        assert repeat(customer, booking).status_code == 409

    def test_only_own_booking_and_not_cancelled(self, customer, make_customer, worker, make_booking,
                                                completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        assert repeat(make_customer(), booking).status_code == 404
        assert client_for(worker.user).post(URL + "from-booking/", {}, format="json").status_code == 403
        from apps.jobs.services import cancel_booking

        cancelled = cancel_booking(make_booking(customer, worker), customer, "Changed my mind")
        assert repeat(customer, cancelled).status_code == 409

    @pytest.mark.parametrize("when", [timedelta(hours=1), timedelta(days=61)])
    def test_first_visit_window(self, when, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        resp = repeat(customer, booking, first_visit=timezone.now() + when)
        assert resp.status_code == 400

    def test_bad_frequency(self, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        assert repeat(customer, booking, "daily").status_code == 400


@pytest.mark.django_db
class TestVisits:
    def test_visit_goes_to_the_usual_worker_two_days_ahead(self, plan, worker, make_worker,
                                                           django_capture_on_commit_callbacks):
        other = make_worker()
        first = plan.next_visit
        with django_capture_on_commit_callbacks(execute=True):
            assert create_recurring_visits() == 1
        visit = RecurringVisit.objects.get(plan=plan)
        assert visit.outcome == "worker" and visit.scheduled_for == first
        req = visit.request
        assert req.invited_worker == worker and req.preferred_time == first and req.is_open
        assert Notification.objects.filter(user=worker.user, type=Notification.Type.NEW_REQUEST).exists()
        assert not Notification.objects.filter(user=other.user, type=Notification.Type.NEW_REQUEST).exists()
        plan.refresh_from_db()
        assert plan.next_visit == first + timedelta(days=7)
        # Running again does nothing: the next visit is a week away.
        assert services.create_due_visits() == 0
        # Customer sees the visit and its request.
        body = data(client_for(plan.customer).get(f"{URL}{plan.pk}/"))
        assert body["recent_visits"][0]["request_id"] == req.pk and body["recent_visits"][0]["outcome"] == "worker"

    def test_far_visits_wait(self, customer, worker, completed_booking_factory):
        repeat(customer, completed_booking_factory(customer, worker), first_visit=in_days(5))
        assert services.create_due_visits() == 0
        assert RecurringVisit.objects.count() == 0

    def test_busy_worker_means_everyone_nearby(self, plan, worker, make_worker, django_capture_on_commit_callbacks):
        other = make_worker()
        day = timezone.localtime(plan.next_visit).date()
        TimeOff.objects.create(worker=worker, start_date=day, end_date=day)
        with django_capture_on_commit_callbacks(execute=True):
            assert services.create_due_visits() == 1
        visit = RecurringVisit.objects.get(plan=plan)
        assert visit.outcome == "all" and visit.request.invited_worker is None
        assert ServiceRequest.objects.filter(customer=plan.customer, invited_worker=worker,
                                             preferred_time=plan.next_visit).count() == 0  # rolled back
        assert Notification.objects.filter(user=other.user, type=Notification.Type.NEW_REQUEST).exists()
        msg = Notification.objects.get(user=plan.customer, type=Notification.Type.RECURRING)
        assert msg.data["request_id"] == visit.request.pk
        # The plan keeps its usual worker for next time.
        plan.refresh_from_db()
        assert plan.worker == worker

    def test_failed_visit_tells_the_customer(self, plan, category):
        category.is_active = False
        category.save()
        assert services.create_due_visits() == 1
        visit = RecurringVisit.objects.get(plan=plan)
        assert visit.outcome == "failed" and visit.request is None and visit.note
        assert Notification.objects.filter(user=plan.customer, type=Notification.Type.RECURRING).exists()

    def test_missed_visits_after_downtime_are_skipped(self, plan):
        RecurringJob.objects.filter(pk=plan.pk).update(next_visit=timezone.now() - timedelta(days=15))
        assert services.create_due_visits() == 0
        plan.refresh_from_db()
        assert plan.next_visit > timezone.now() + services.LEAD
        assert RecurringVisit.objects.count() == 0

    def test_paused_and_cancelled_plans_are_skipped(self, plan):
        services.pause(plan, plan.customer)
        assert services.create_due_visits() == 0

    def test_no_visit_created_twice(self, plan):
        RecurringVisit.objects.create(plan=plan, scheduled_for=plan.next_visit, outcome="worker")
        assert services.create_due_visits() == 0
        assert ServiceRequest.objects.filter(preferred_time=plan.next_visit).count() == 0

    def test_after_the_worker_leaves_visits_go_to_everyone(self, plan, worker, django_capture_on_commit_callbacks):
        resp = client_for(worker.user).post(f"{URL}{plan.pk}/leave/")
        assert resp.status_code == 200 and "address" not in data(resp)
        assert Notification.objects.filter(user=plan.customer, type=Notification.Type.RECURRING).exists()
        with django_capture_on_commit_callbacks(execute=True):
            services.create_due_visits()
        visit = RecurringVisit.objects.get(plan=plan)
        assert visit.outcome == "all"
        # The worker no longer sees the plan.
        assert data(client_for(worker.user).get(URL))["results"] == []

    def test_worker_can_offer_on_the_visit(self, plan, worker, make_offer, django_capture_on_commit_callbacks):
        with django_capture_on_commit_callbacks(execute=True):
            services.create_due_visits()
        req = RecurringVisit.objects.get(plan=plan).request
        offer = make_offer(worker, req)
        assert offer.status == WorkerOffer.Status.PENDING


@pytest.mark.django_db
class TestManage:
    def test_pause_resume_skips_missed(self, plan):
        c = client_for(plan.customer)
        assert data(c.post(f"{URL}{plan.pk}/pause/"))["status"] == "paused"
        assert c.post(f"{URL}{plan.pk}/pause/").status_code == 409
        RecurringJob.objects.filter(pk=plan.pk).update(next_visit=timezone.now() - timedelta(days=8))
        body = data(c.post(f"{URL}{plan.pk}/resume/"))
        assert body["status"] == "active"
        assert datetime.fromisoformat(body["next_visit"]) > timezone.now() + timedelta(hours=2)

    def test_skip_next_and_cancel(self, plan):
        c = client_for(plan.customer)
        first = plan.next_visit
        body = data(c.post(f"{URL}{plan.pk}/skip-next/"))
        assert datetime.fromisoformat(body["next_visit"]) == first + timedelta(days=7)
        assert data(c.post(f"{URL}{plan.pk}/cancel/"))["status"] == "cancelled"
        assert c.post(f"{URL}{plan.pk}/cancel/").status_code == 409
        assert c.post(f"{URL}{plan.pk}/resume/").status_code == 409
        assert data(c.get(URL + "?status=cancelled"))["count"] == 1

    def test_change_frequency_and_next_visit(self, plan):
        c = client_for(plan.customer)
        when = in_days(10, 9)
        resp = c.patch(f"{URL}{plan.pk}/", {"frequency": "monthly", "next_visit": when.isoformat(), "budget": "2500"},
                       format="json")
        body = data(resp)
        assert body["frequency"] == "monthly" and body["budget"] == "2500.00"
        assert datetime.fromisoformat(body["next_visit"]) == when
        assert c.patch(f"{URL}{plan.pk}/", {"next_visit": timezone.now().isoformat()}, format="json").status_code == 400

    def test_access(self, plan, worker, make_customer, make_worker, api):
        assert api.get(URL).status_code == 401
        stranger = make_customer()
        assert data(client_for(stranger).get(URL))["results"] == []
        assert client_for(stranger).get(f"{URL}{plan.pk}/").status_code == 404
        assert client_for(stranger).post(f"{URL}{plan.pk}/pause/").status_code == 404
        # The worker sees it without the address; cannot pause or edit it.
        w = client_for(worker.user)
        body = data(w.get(f"{URL}{plan.pk}/"))
        assert "address" not in body and "description" not in body and body["customer_name"]
        assert w.post(f"{URL}{plan.pk}/pause/").status_code == 403
        assert w.patch(f"{URL}{plan.pk}/", {"frequency": "monthly"}, format="json").status_code == 403
        # Another worker cannot leave it.
        assert client_for(make_worker().user).post(f"{URL}{plan.pk}/leave/").status_code == 404


class TestAddPeriod:
    def test_weekly_biweekly(self):
        start = datetime(2026, 3, 2, 10, tzinfo=PKT)
        assert services.add_period(start, "weekly") == start + timedelta(days=7)
        assert services.add_period(start, "biweekly") == start + timedelta(days=14)

    def test_monthly_keeps_day_and_caps(self):
        assert services.add_period(datetime(2026, 1, 31, 10, tzinfo=PKT), "monthly") == datetime(
            2026, 2, 28, 10, tzinfo=PKT)
        assert services.add_period(datetime(2026, 12, 15, 10, tzinfo=PKT), "monthly") == datetime(
            2027, 1, 15, 10, tzinfo=PKT)
