from celery import shared_task

from . import services


@shared_task
def create_recurring_visits():
    return services.create_due_visits()
