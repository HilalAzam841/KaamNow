"""Firebase Cloud Messaging sender (HTTP v1 API).

Configure with FCM_PROJECT_ID and FCM_CREDENTIALS_FILE (service-account JSON
with the "Firebase Cloud Messaging API" enabled). Sending happens in a Celery
task so API requests never wait on Google.
"""

import logging
import threading

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FCM_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"
# Errors that mean the token will never work again.
DEAD_TOKEN_ERRORS = {"UNREGISTERED", "NOT_FOUND"}

_lock = threading.Lock()
_credentials = None


def is_configured():
    return bool(settings.FCM_PROJECT_ID and settings.FCM_CREDENTIALS_FILE)


def _access_token():
    global _credentials
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account

    with _lock:
        if _credentials is None:
            _credentials = service_account.Credentials.from_service_account_file(
                settings.FCM_CREDENTIALS_FILE, scopes=[FCM_SCOPE]
            )
        if not _credentials.valid:
            _credentials.refresh(Request())
        return _credentials.token


def build_message(token, title, body, data):
    return {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            # FCM data values must be strings.
            "data": {str(k): str(v) for k, v in (data or {}).items()},
            "android": {"priority": "high", "notification": {"channel_id": "kaamnow_default"}},
        }
    }


def _error_status(response):
    try:
        error = response.json().get("error", {})
    except ValueError:
        return ""
    for detail in error.get("details", []):
        if detail.get("errorCode"):
            return detail["errorCode"]
    return error.get("status", "")


def send_to_token(token, title, body, data):
    """Returns 'sent', 'dead' (token should be deactivated) or 'failed'."""
    url = FCM_URL.format(project=settings.FCM_PROJECT_ID)
    try:
        response = requests.post(
            url, json=build_message(token, title, body, data),
            headers={"Authorization": f"Bearer {_access_token()}"}, timeout=10,
        )
    except requests.RequestException:
        logger.exception("FCM request failed")
        return "failed"
    if response.status_code == 200:
        return "sent"
    status = _error_status(response)
    if response.status_code == 404 or status in DEAD_TOKEN_ERRORS:
        return "dead"
    if status == "INVALID_ARGUMENT" and "token" in response.text.lower():
        return "dead"
    logger.warning("FCM send failed (%s): %s", response.status_code, response.text[:300])
    return "failed"
