from celery import shared_task

from .services import auto_complete_finished_jobs as _auto_complete
from .services import expire_stale_requests as _expire


@shared_task
def expire_stale_requests():
    return _expire()


@shared_task
def auto_complete_finished_jobs():
    return _auto_complete()
