"""Notification service.

Every notification is stored in the database (in-app history) and sent as a
push notification through `get_push_sender()`. When Firebase is configured
the FCM sender queues a Celery task per recipient; otherwise pushes are
skipped and only the in-app history is kept.
"""

import logging

from django.conf import settings
from django.db import transaction
from django.utils import timezone, translation

from . import fcm
from .models import Notification

logger = logging.getLogger(__name__)


class NullPushSender:
    def send(self, user, title, body, data):
        logger.debug("Push (FCM not configured) to user %s: %s", user.pk, title)


class FCMPushSender:
    def send(self, user, title, body, data):
        from .tasks import send_push

        payload = {k: (str(v) if not isinstance(v, (str, int, float, bool)) else v) for k, v in (data or {}).items()}
        transaction.on_commit(lambda: send_push.delay(user.pk, title, body, payload))


def get_push_sender():
    return FCMPushSender() if fcm.is_configured() else NullPushSender()


def render_for(user, *texts):
    """Renders lazy (gettext_lazy / format_lazy) texts in the recipient's own language.

    Alerts are written when something happens, often in another user's request or in a
    background task, so the language comes from the recipient's account, not the request.
    """
    language = getattr(user, "language", "") or settings.LANGUAGE_CODE
    with translation.override(language):
        return [str(t) for t in texts]


def push_only(user, type, title, body, data=None):
    """Push without storing in-app history (used for high-volume events such as chat messages)."""
    title, body = render_for(user, title, body)
    get_push_sender().send(user, title, body, {**(data or {}), "type": type})


def notify(user, type, title, body, data=None):
    data = data or {}
    title, body = render_for(user, title, body)
    notification = Notification.objects.create(user=user, type=type, title=title, body=body, data=data)
    get_push_sender().send(user, title, body, {**data, "type": type, "notification_id": notification.pk})
    return notification


def notify_many(users, type, title, body, data=None):
    data = data or {}
    rendered = [(u, *render_for(u, title, body)) for u in users]
    objs = [Notification(user=u, type=type, title=t, body=b, data=data) for u, t, b in rendered]
    created = Notification.objects.bulk_create(objs)
    sender = get_push_sender()
    for u, t, b in rendered:
        sender.send(u, t, b, {**data, "type": type})
    return created


def mark_read(notification):
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save(update_fields=["is_read", "read_at"])
    return notification
