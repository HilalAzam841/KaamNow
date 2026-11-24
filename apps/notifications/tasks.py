from celery import shared_task

from . import fcm
from .models import DeviceToken


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
