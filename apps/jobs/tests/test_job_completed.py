"""The customer taps "Job completed"; the worker can say they finished and remind the customer.
If the customer does not answer, the job completes on its own so the worker is free again."""

from datetime import datetime, timedelta

import pytest
from django.conf import settings
from django.utils import timezone

from apps.jobs.models import Booking
from apps.jobs.services import auto_complete_finished_jobs
from apps.notifications.models import Notification
from conftest import advance_to, client_for, data

pytestmark = pytest.mark.django_db
URL = "/api/v1/bookings/"


@pytest.fixture
def working(customer, worker, make_booking):
    return advance_to(make_booking(customer, worker), Booking.Status.IN_PROGRESS)


class TestWorkerFinished:
    def test_worker_says_finished_and_customer_is_asked(self, customer, worker, working):
        body = data(client_for(worker.user).post(f"{URL}{working.pk}/finished/"))
        assert body["status"] == "in_progress" and body["worker_finished_at"]
        working.refresh_from_db()
        hours = settings.KAAMNOW["JOB_AUTO_COMPLETE_HOURS"]
        auto = datetime.fromisoformat(body["auto_complete_at"].replace("Z", "+00:00"))
        assert auto == working.worker_finished_at + timedelta(hours=hours)
        n = Notification.objects.filter(user=customer, title="Is the job done?").get()
        assert n.data == {"booking_id": working.pk}
        assert data(client_for(customer).get(f"{URL}{working.pk}/"))["worker_finished_at"]

    def test_reminder_has_a_cooldown_and_keeps_the_time(self, customer, worker, working):
        w = client_for(worker.user)
        first = data(w.post(f"{URL}{working.pk}/finished/"))["worker_finished_at"]
        assert w.post(f"{URL}{working.pk}/finished/").status_code == 429
        from django.core.cache import cache

        cache.delete(f"worker-finished-remind:{working.pk}")
        assert data(w.post(f"{URL}{working.pk}/finished/"))["worker_finished_at"] == first
        assert Notification.objects.filter(user=customer, title="Is the job done?").count() == 2

    def test_only_the_worker_and_only_while_working(self, customer, worker, make_booking, make_worker):
        booking = make_booking(customer, worker)
        assert client_for(worker.user).post(f"{URL}{booking.pk}/finished/").status_code == 409
        booking = advance_to(booking, Booking.Status.IN_PROGRESS)
        assert client_for(customer).post(f"{URL}{booking.pk}/finished/").status_code == 403
        assert client_for(make_worker(name="Kamran Ali").user).post(f"{URL}{booking.pk}/finished/").status_code == 404


class TestCustomer:
    def test_job_completed_button_frees_the_worker(self, customer, worker, working):
        client_for(worker.user).post(f"{URL}{working.pk}/finished/")
        body = data(client_for(customer).post(f"{URL}{working.pk}/complete/", {"confirm": True}))
        assert body["status"] == "completed" and body["completed_via"] == "customer_confirmation"
        assert body["auto_complete_at"] is None
        assert not Booking.objects.filter(worker=worker, status__in=Booking.ACTIVE_STATUSES).exists()

    def test_customer_can_complete_without_waiting_for_the_worker(self, customer, working):
        body = data(client_for(customer).post(f"{URL}{working.pk}/complete/", {"confirm": True}))
        assert body["status"] == "completed"

    def test_not_finished_yet_tells_the_worker(self, customer, worker, working):
        client_for(worker.user).post(f"{URL}{working.pk}/finished/")
        c = client_for(customer)
        assert c.post(f"{URL}{working.pk}/not-finished/", {"reason": ""}).status_code == 400
        body = data(c.post(f"{URL}{working.pk}/not-finished/", {"reason": "The tap still leaks"}))
        assert body["status"] == "in_progress" and body["worker_finished_at"] is None
        assert body["auto_complete_at"] is None
        n = Notification.objects.get(user=worker.user, title="Not finished yet")
        assert "The tap still leaks" in n.body
        # The worker can say finished again straight away after fixing it.
        assert client_for(worker.user).post(f"{URL}{working.pk}/finished/").status_code == 200

    def test_not_finished_needs_the_worker_to_have_said_finished(self, customer, worker, working):
        assert client_for(customer).post(f"{URL}{working.pk}/not-finished/", {"reason": "Not done"}).status_code == 409
        client_for(worker.user).post(f"{URL}{working.pk}/finished/")
        assert client_for(worker.user).post(f"{URL}{working.pk}/not-finished/",
                                            {"reason": "Not done"}).status_code == 403


class TestAutoComplete:
    def test_completes_after_the_wait_if_the_customer_does_not_answer(self, customer, worker, working):
        client_for(worker.user).post(f"{URL}{working.pk}/finished/")
        assert auto_complete_finished_jobs() == 0
        hours = settings.KAAMNOW["JOB_AUTO_COMPLETE_HOURS"]
        Booking.objects.filter(pk=working.pk).update(worker_finished_at=timezone.now() - timedelta(hours=hours, minutes=1))
        assert auto_complete_finished_jobs() == 1
        working.refresh_from_db()
        assert (working.status, working.completed_via) == ("completed", "auto")
        worker.refresh_from_db()
        assert worker.completed_jobs_count == 1
        assert hasattr(working, "commission")
        assert auto_complete_finished_jobs() == 0

    def test_jobs_not_marked_finished_are_left_alone(self, working):
        Booking.objects.filter(pk=working.pk).update(started_at=timezone.now() - timedelta(days=3))
        assert auto_complete_finished_jobs() == 0
        working.refresh_from_db()
        assert working.status == "in_progress"
