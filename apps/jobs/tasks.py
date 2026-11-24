from celery import shared_task

from .services import expire_stale_requests as _expire


@shared_task
def expire_stale_requests():
    return _expire()
