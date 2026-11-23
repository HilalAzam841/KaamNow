"""Notification service.

Stage 1 stores notifications in the database (in-app history). Push
delivery goes through `get_push_sender()`; the default sender is a no-op
until the Firebase Cloud Messaging sender is added in Stage 2.
"""

import logging

from django.utils import timezone

from .models import Notification

logger = logging.getLogger(__name__)


class NullPushSender:
    def send(self, user, title, body, data):
        logger.debug("Push (disabled) to user %s: %s", user.pk, title)


def get_push_sender():
    return NullPushSender()


def notify(user, type, title, body, data=None):
    data = data or {}
    notification = Notification.objects.create(user=user, type=type, title=title, body=body, data=data)
    get_push_sender().send(user, title, body, data)
    return notification


def notify_many(users, type, title, body, data=None):
    data = data or {}
    objs = [Notification(user=u, type=type, title=title, body=body, data=data) for u in users]
    created = Notification.objects.bulk_create(objs)
    sender = get_push_sender()
    for u in users:
        sender.send(u, title, body, data)
    return created


def mark_read(notification):
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save(update_fields=["is_read", "read_at"])
    return notification
