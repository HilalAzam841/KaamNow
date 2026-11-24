from celery import shared_task

from . import services


@shared_task
def expire_stale_online_payments():
    return services.expire_stale_online_payments()


@shared_task
def expire_subscriptions_and_featured():
    return services.expire_subscriptions_and_featured()
