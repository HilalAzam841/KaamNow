from datetime import timedelta

import pytest
from django.utils import timezone

from apps.jobs.models import ServiceRequest
from apps.jobs.tasks import expire_stale_requests
from apps.offers.models import WorkerOffer

pytestmark = pytest.mark.django_db


def test_expire_stale_requests(customer, worker, make_request, make_offer):
    stale = make_request(customer)
    offer = make_offer(worker, stale)
    fresh = make_request(customer)
    ServiceRequest.objects.filter(pk=stale.pk).update(preferred_time=timezone.now() - timedelta(hours=25))
    assert expire_stale_requests() == 1  # runs eagerly as a Celery task
    stale.refresh_from_db()
    fresh.refresh_from_db()
    offer.refresh_from_db()
    assert stale.status == "expired" and fresh.status == "open"
    assert offer.status == WorkerOffer.Status.CLOSED


def test_celery_beat_schedule_points_to_real_tasks():
    from django.conf import settings

    from config.celery import app

    app.loader.import_default_modules()
    for entry in settings.CELERY_BEAT_SCHEDULE.values():
        assert entry["task"] in app.tasks, entry["task"]
