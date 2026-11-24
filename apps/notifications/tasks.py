from celery import shared_task

from . import fcm, webpush
from .models import DeviceToken, WebPushSubscription


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_push(self, user_id, title, body, data=None):
    """Sends a push notification to every active device of the user."""
    if not fcm.is_configured():
        return {"sent": 0, "skipped": "fcm_not_configured"}
    tokens = list(DeviceToken.objects.filter(user_id=user_id, is_active=True).values_list("id", "token"))
    sent, dead, failed = 0, [], 0
    for token_id, token in tokens:
        result = fcm.send_to_token(token, title, body, data or {})
        if result == "sent":
            sent += 1
        elif result == "dead":
            dead.append(token_id)
        else:
            failed += 1
    if dead:
        DeviceToken.objects.filter(id__in=dead).update(is_active=False)
    if failed and not sent:
        raise self.retry()
    return {"sent": sent, "deactivated": len(dead), "failed": failed}


# Alerts that people want to see right away; the rest can wait for the phone to wake up.
URGENT_TYPES = {"chat_message", "new_offer", "new_request", "negotiation", "offer_accepted", "booking_status",
                "booking_cancelled"}


def deep_link(user, data):
    """The screen the notification opens when tapped (the web app uses hash URLs)."""
    booking_id, request_id = data.get("booking_id"), data.get("request_id")
    kind = data.get("type")
    if kind == "chat_message" and booking_id:
        return f"/#/bookings/{booking_id}/chat"
    if booking_id:
        return f"/#/bookings/{booking_id}"
    if request_id:
        return f"/#/jobs/{request_id}" if getattr(user, "is_worker", False) else f"/#/requests/{request_id}"
    if kind == "complaint":
        return "/#/complaints"
    if kind in ("verification", "subscription", "featured"):
        return "/#/worker/profile" if kind == "verification" else "/#/worker/plans"
    return "/#/notifications"


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_web_push(self, user_id, title, body, data=None):
    """Sends a browser notification to every browser the user turned notifications on in."""
    from django.contrib.auth import get_user_model

    if not webpush.is_configured():
        return {"sent": 0, "skipped": "web_push_not_configured"}
    data = data or {}
    user = get_user_model().objects.filter(pk=user_id).first()
    subscriptions = list(WebPushSubscription.objects.filter(user_id=user_id, is_active=True))
    if user is None or not subscriptions:
        return {"sent": 0}
    kind = data.get("type", "")
    payload = {
        "title": title,
        "body": body,
        "url": deep_link(user, data),
        "type": kind,
        "tag": f"chat-{data['booking_id']}" if kind == "chat_message" and data.get("booking_id") else "",
        "notification_id": data.get("notification_id"),
    }
    urgency = "high" if kind in URGENT_TYPES else "normal"
    sent, dead, failed = 0, [], 0
    for subscription in subscriptions:
        result = webpush.send(subscription, payload, urgency=urgency)
        if result == "sent":
            sent += 1
        elif result == "dead":
            dead.append(subscription.pk)
        else:
            failed += 1
    if dead:
        WebPushSubscription.objects.filter(pk__in=dead).update(is_active=False)
    if failed and not sent:
        raise self.retry()
    return {"sent": sent, "deactivated": len(dead), "failed": failed}
