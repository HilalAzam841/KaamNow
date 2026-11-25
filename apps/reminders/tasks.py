from celery import shared_task

from . import services


@shared_task
def send_booking_reminders():
    return services.send_due_reminders()
