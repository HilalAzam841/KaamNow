"""Worker levels and badges."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.accounts.models import WorkerProfile
from apps.favourites.models import FavouriteWorker
from apps.jobs.models import Booking
from apps.levels import services
from apps.levels.tasks import refresh_worker_levels
from apps.notifications.models import Notification
from apps.reminders.models import NoShowReport
from conftest import client_for, data

pytestmark = pytest.mark.django_db
LEVEL = "/api/v1/workers/me/level/"


def set_stats(worker, jobs=0, rating="0.00", reviews=0):
    WorkerProfile.objects.filter(pk=worker.pk).update(
        completed_jobs_count=jobs, average_rating=Decimal(rating), rating_count=reviews)


def bookings(customer, worker, make_booking, n, cancelled_by_worker=0):
    """n bookings in the last 90 days, the first `cancelled_by_worker` of them cancelled by the worker
    and the rest completed."""
    out = []
    for i in range(n):
        b = make_booking(customer, worker)
        if i < cancelled_by_worker:
            Booking.objects.filter(pk=b.pk).update(status=Booking.Status.CANCELLED, cancelled_by=worker.user)
        else:  # finished, so the worker can take the next one
            Booking.objects.filter(pk=b.pk).update(status=Booking.Status.COMPLETED)
        out.append(b)
    return out


def no_show(booking, worker, customer, review="confirmed", days_ago=1):
    r = NoShowReport.objects.create(booking=booking, side="worker", reported_by=customer, against=worker.user,
                                    review=review)
    NoShowReport.objects.filter(pk=r.pk).update(created_at=timezone.now() - timedelta(days=days_ago))


class TestLevels:
    @pytest.mark.parametrize("jobs,rating,reviews,expected", [
        (0, "0.00", 0, "new"),
        (3, "0.00", 0, "rising"),  # not rated yet
        (3, "3.90", 2, "new"),
        (15, "4.40", 4, "rising"),  # needs 5 reviews for trusted
        (15, "4.40", 5, "trusted"),
        (50, "4.80", 19, "trusted"),
        (50, "4.80", 20, "top_rated"),
        (80, "4.60", 40, "trusted"),
    ])
    def test_levels_from_jobs_and_ratings(self, worker, jobs, rating, reviews, expected):
        set_stats(worker, jobs, rating, reviews)
        assert services.refresh(worker).level == expected

    def test_unverified_workers_stay_new(self, make_worker):
        w = make_worker(verified=False)
        set_stats(w, 60, "4.90", 30)
        assert services.refresh(w).level == "new"

    def test_no_shows_and_cancellations_hold_a_worker_back(self, worker, customer, make_booking):
        set_stats(worker, 60, "4.90", 30)
        made = bookings(customer, worker, make_booking, 10)
        no_show(made[0], worker, customer)
        assert services.refresh(worker).level == "trusted", "one confirmed no-show is too many for top rated"
        no_show(made[1], worker, customer)
        assert services.refresh(worker).level == "rising", "two are too many for trusted"
        NoShowReport.objects.all().update(created_at=timezone.now() - timedelta(days=91))
        assert services.refresh(worker).level == "top_rated", "only the last 90 days count"
        NoShowReport.objects.create(booking=made[2], side="worker", reported_by=customer, against=worker.user,
                                    review="dismissed")
        assert services.refresh(worker).level == "top_rated", "dismissed reports don't count"

    def test_cancel_rate(self, worker, customer, make_booking):
        set_stats(worker, 60, "4.90", 30)
        bookings(customer, worker, make_booking, 10, cancelled_by_worker=1)  # 10%
        assert services.refresh(worker).level == "trusted"
        assert services.progress(worker)["stats"]["cancel_rate"] == Decimal("10.0")

    def test_moving_up_is_announced_once_and_moving_down_quietly(self, worker, django_capture_on_commit_callbacks):
        set_stats(worker, 15, "4.50", 6)
        with django_capture_on_commit_callbacks(execute=True):
            services.refresh(worker)
            services.refresh(worker)
        n = Notification.objects.filter(user=worker.user, type="level")
        assert n.count() == 1 and "Trusted" in n.get().body
        set_stats(worker, 15, "4.00", 6)
        with django_capture_on_commit_callbacks(execute=True):
            w = services.refresh(worker)
        assert w.level == "rising" and w.level_rank == 1
        assert Notification.objects.filter(user=worker.user, type="level").count() == 1

    def test_urdu_notice(self, worker, django_capture_on_commit_callbacks):
        worker.user.language = "ur"
        worker.user.save(update_fields=["language"])
        set_stats(worker, 3)
        with django_capture_on_commit_callbacks(execute=True):
            services.refresh(worker)
        assert "ابھرتا" in Notification.objects.get(user=worker.user, type="level").body


class TestBadges:
    def test_badges(self, worker, customer, make_customer, make_booking):
        WorkerProfile.objects.filter(pk=worker.pk).update(experience_years=6)
        set_stats(worker, 100, "4.50", 10)
        for _ in range(5):
            FavouriteWorker.objects.create(customer=make_customer(), worker=worker)
        done = bookings(customer, worker, make_booking, 10)
        assert services.refresh(worker).badges == [
            "verified", "jobs_100", "experienced", "customer_favourite", "always_on_time"]
        no_show(done[0], worker, customer)
        assert "always_on_time" not in services.refresh(worker).badges


class TestRefreshTriggers:
    def test_completing_a_job_reviewing_and_verifying(self, customer, worker, completed_booking_factory, api,
                                                       make_worker, admin_user):
        WorkerProfile.objects.filter(pk=worker.pk).update(completed_jobs_count=2)
        booking = completed_booking_factory(customer, worker)
        worker.refresh_from_db()
        assert (worker.completed_jobs_count, worker.level) == (3, "rising")
        resp = client_for(customer).post("/api/v1/reviews/", {"booking": booking.pk, "rating": 2})
        assert resp.status_code == 201, resp.json()
        worker.refresh_from_db()
        assert worker.level == "new", "a 2-star average drops below rising"

    def test_worker_cancelling_refreshes(self, customer, worker, make_booking):
        set_stats(worker, 15, "4.50", 6)
        services.refresh(worker)
        booking = make_booking(customer, worker)
        resp = client_for(worker.user).post(f"/api/v1/bookings/{booking.pk}/cancel/", {"reason": "Bike broke down"})
        assert resp.status_code == 200, resp.json()
        worker.refresh_from_db()
        assert worker.level == "rising", "1 of 1 recent bookings cancelled is over 10%"

    def test_confirmed_no_show_refreshes(self, customer, worker, make_booking, admin_user):
        set_stats(worker, 60, "4.90", 30)
        services.refresh(worker)
        b = make_booking(customer, worker)
        r = NoShowReport.objects.create(booking=b, side="worker", reported_by=customer, against=worker.user)
        resp = client_for(admin_user).post(f"/api/v1/admin/no-shows/{r.pk}/review/", {"review": "confirmed"})
        assert resp.status_code == 200, resp.json()
        worker.refresh_from_db()
        assert worker.level == "trusted"

    def test_nightly_task(self, worker, customer, make_booking):
        set_stats(worker, 60, "4.90", 30)
        services.refresh(worker)
        b = make_booking(customer, worker)
        NoShowReport.objects.create(booking=b, side="worker", reported_by=customer, against=worker.user,
                                    review="confirmed")
        assert refresh_worker_levels() == 1
        worker.refresh_from_db()
        assert worker.level == "trusted"
        assert refresh_worker_levels() == 0


class TestApi:
    def test_progress_for_the_next_level(self, worker):
        set_stats(worker, 9, "4.50", 3)
        services.refresh(worker)
        body = data(client_for(worker.user).get(LEVEL))
        assert body["level"] == "rising" and body["next_level"] == "trusted"
        reqs = {r["key"]: r for r in body["requirements"]}
        assert reqs["jobs"] == {"key": "jobs", "target": "15.0", "value": "9.00", "met": False}
        assert reqs["rating"]["met"] is True and reqs["reviews"]["met"] is False
        assert reqs["no_shows"]["met"] is True and reqs["cancel_rate"]["met"] is True
        assert body["window_days"] == 90 and body["verified"] is True

    def test_top_rated_has_nothing_next(self, worker):
        set_stats(worker, 60, "4.90", 30)
        body = data(client_for(worker.user).get(LEVEL))
        assert body["level"] == "top_rated" and body["next_level"] is None and body["requirements"] == []

    def test_only_workers(self, customer):
        assert client_for(customer).get(LEVEL).status_code == 403

    def test_level_is_public_and_filters_listings(self, worker, make_worker, api, category):
        set_stats(worker, 60, "4.90", 30)
        services.refresh(worker)
        other = make_worker(name="Kamran Ali")
        card = data(api.get(f"/api/v1/workers/{worker.pk}/"))
        assert card["level"] == "top_rated" and "verified" in card["badges"]
        listings = data(api.get("/api/v1/services/workers/", {"category": category.pk, "min_level": "trusted"}))
        rows = listings["results"] if isinstance(listings, dict) else listings
        assert [r["worker_id"] for r in rows] == [worker.pk]
        assert rows[0]["worker_level"] == "top_rated"
        both = data(api.get("/api/v1/services/workers/", {"category": category.pk, "ordering": "-worker__level_rank"}))
        rows = both["results"] if isinstance(both, dict) else both
        assert [r["worker_id"] for r in rows][:2] == [worker.pk, other.pk]
        mine = data(client_for(worker.user).get("/api/v1/workers/me/"))
        assert mine["level"] == "top_rated"
