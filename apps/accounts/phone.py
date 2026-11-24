"""One-time SMS codes: confirming a phone number and resetting a forgotten password.

Codes are random, stored only as an HMAC, expire after a few minutes, allow a handful of
attempts and then burn, can be re-sent only after a cooldown, and each number gets a daily cap so
the service cannot be used to flood someone with SMS.
"""

import hashlib
import hmac
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone, translation
from django.utils.translation import gettext as _

from apps.common import sms
from apps.common.exceptions import BusinessRuleError

from .models import PhoneCode, User

logger = logging.getLogger(__name__)


class CodeCooldown(BusinessRuleError):
    status_code = 429
    default_code = "code_cooldown"


def _cfg(name):
    return settings.KAAMNOW[name]


def _hash(phone, purpose, code):
    key = settings.SECRET_KEY.encode()
    return hmac.new(key, f"phone-code:{purpose}:{phone}:{code}".encode(), hashlib.sha256).hexdigest()


def _generate():
    length = _cfg("PHONE_CODE_LENGTH")
    return "".join(secrets.choice("0123456789") for _ in range(length))


def verification_required():
    return bool(settings.PHONE_VERIFICATION_REQUIRED)


def require_verified(user):
    """Called before posting a job or sending an offer."""
    if verification_required() and not user.is_platform_admin and not user.phone_verified:
        raise BusinessRuleError(
            _("Confirm your phone number first. We will send you a code by SMS."),
            code="phone_not_verified",
            status_code=403,
        )


def issue_code(phone, purpose, *, language="en"):
    """Creates a code for this number and sends it by SMS. Raises CodeCooldown when asked again
    too soon or too often, and BusinessRuleError when the SMS could not be sent."""
    now = timezone.now()
    with transaction.atomic():
        # Serialise requests for the same number so the cooldown and daily cap hold under races.
        list(User.objects.select_for_update().filter(phone=phone).values_list("pk", flat=True))
        recent = PhoneCode.objects.filter(phone=phone, purpose=purpose)
        last = recent.order_by("-created_at").first()
        wait = _cfg("PHONE_CODE_RESEND_SECONDS")
        if last and (now - last.created_at).total_seconds() < wait:
            seconds = int(wait - (now - last.created_at).total_seconds()) + 1
            raise CodeCooldown(_("Please wait %(seconds)s seconds before asking for a new code.") % {"seconds": seconds})
        if recent.filter(created_at__gte=now - timedelta(days=1)).count() >= _cfg("PHONE_CODE_DAILY_LIMIT"):
            raise CodeCooldown(_("Too many codes requested for this number today. Please try again tomorrow."))
        code = _generate()
        recent.filter(used_at__isnull=True).update(used_at=now)  # only the newest code works
        PhoneCode.objects.create(
            phone=phone, purpose=purpose, code_hash=_hash(phone, purpose, code),
            expires_at=now + timedelta(minutes=_cfg("PHONE_CODE_TTL_MINUTES")), created_at=now,
        )
    with translation.override(language):
        text = _("Your KaamNow code is %(code)s. It expires in %(minutes)s minutes. Never share it with anyone.") % {
            "code": code, "minutes": _cfg("PHONE_CODE_TTL_MINUTES"),
        }
    try:
        sms.send(phone, text)
    except sms.SmsError as exc:
        logger.error("Could not send %s code: %s", purpose, exc)
        raise BusinessRuleError(_("We could not send the SMS. Please try again in a few minutes."), status_code=503) from exc


def check_code(phone, purpose, code):
    """True and burns the code if it matches the newest live code. Failed attempts are counted and
    saved; after the limit the code stops working."""
    code = (code or "").strip()
    now = timezone.now()
    with transaction.atomic():
        current = (
            PhoneCode.objects.select_for_update()
            .filter(phone=phone, purpose=purpose, used_at__isnull=True, expires_at__gt=now)
            .order_by("-created_at")
            .first()
        )
        if current is None:
            return False
        if hmac.compare_digest(current.code_hash, _hash(phone, purpose, code)):
            current.used_at = now
            current.save(update_fields=["used_at"])
            return True
        current.attempts += 1
        if current.attempts >= _cfg("PHONE_CODE_MAX_ATTEMPTS"):
            current.used_at = now
        current.save(update_fields=["attempts", "used_at"])
        return False
