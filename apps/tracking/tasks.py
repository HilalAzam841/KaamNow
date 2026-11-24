from celery import shared_task

from .services import purge_old_locations as _purge


@shared_task
def purge_old_locations():
    return _purge()
