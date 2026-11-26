import logging

from celery import shared_task

from . import services

logger = logging.getLogger(__name__)


@shared_task
def refresh_worker_levels():
    changed = services.refresh_all()
    logger.info("Worker levels refreshed: %s changed", changed)
    return changed
