"""Sending SMS. Used for one-time codes (phone verification, password reset).

Backends (settings.SMS_BACKEND):
- "console": writes the message to the log. For development only.
- "twilio": Twilio's Messages API (works for Pakistani numbers). Needs TWILIO_ACCOUNT_SID,
  TWILIO_AUTH_TOKEN and TWILIO_FROM.
"""

import logging

import requests
from django.conf import settings

logger = logging.getLogger(__name__)
TIMEOUT_SECONDS = 10
TWILIO_URL = "https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"


class SmsError(Exception):
    pass


def backend():
    return (settings.SMS_BACKEND or "console").lower()


def is_configured():
    """True when messages reach real phones."""
    if backend() == "twilio":
        return bool(settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN and settings.TWILIO_FROM)
    return False


def is_available():
    """True when codes can be delivered somewhere: a real SMS service, or the log while developing."""
    return is_configured() or (backend() == "console" and settings.DEBUG)


def send(phone: str, text: str) -> None:
    """Sends one SMS to a +92 number. Raises SmsError if it could not be handed to the provider."""
    name = backend()
    if name == "console":
        logger.warning("SMS to %s: %s", phone, text)
        return
    if name == "twilio":
        if not is_configured():
            raise SmsError("Twilio is not configured.")
        try:
            resp = requests.post(
                TWILIO_URL.format(sid=settings.TWILIO_ACCOUNT_SID),
                data={"To": phone, "From": settings.TWILIO_FROM, "Body": text},
                auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN),
                timeout=TIMEOUT_SECONDS,
            )
        except requests.RequestException as exc:
            raise SmsError(f"Twilio request failed: {exc.__class__.__name__}") from exc
        if resp.status_code not in (200, 201):
            # Twilio's error body has a code and message, never the SMS text.
            raise SmsError(f"Twilio rejected the message ({resp.status_code}): {resp.text[:200]}")
        return
    raise SmsError(f"Unknown SMS_BACKEND {name!r}.")
