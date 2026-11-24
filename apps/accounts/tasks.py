from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from .models import PhoneCode


@shared_task
def purge_old_phone_codes():
    """SMS codes are only needed for a day (the daily limit looks back 24 hours)."""
    deleted, _ = PhoneCode.objects.filter(created_at__lt=timezone.now() - timedelta(days=2)).delete()
    return deleted
