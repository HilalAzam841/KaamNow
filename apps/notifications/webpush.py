"""Standard Web Push (RFC 8030) with VAPID (RFC 8292) and aes128gcm payload encryption (RFC 8291).

Browsers (Chrome, Edge, Firefox, Safari on macOS and on iPhone for installed web apps) give the
app a push *subscription*: an endpoint URL at the browser vendor's push service plus two keys.
The server encrypts each message for that browser and posts it to the endpoint. No Firebase
project or other third-party account is needed; only a VAPID key pair, generated with
`python manage.py generate_vapid_keys`.
"""

import base64
import json
import logging
import os
import time
from urllib.parse import urlsplit

import jwt
import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from django.conf import settings
from django.utils.translation import gettext as _

logger = logging.getLogger(__name__)

# Only the browsers' own push services. Endpoints come from the client, so anything else is
# refused rather than letting the server post to arbitrary URLs.
ALLOWED_PUSH_HOSTS = (
    "fcm.googleapis.com",          # Chrome, Edge (Chromium), Samsung Internet, Opera
    ".push.services.mozilla.com",  # Firefox
    ".notify.windows.com",         # legacy Edge
    "web.push.apple.com",          # Safari
    ".push.apple.com",
)
RECORD_SIZE = 4096
TIMEOUT_SECONDS = 10


class InvalidSubscription(ValueError):
    pass


def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def b64url_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def is_configured():
    return bool(settings.WEBPUSH_VAPID_PUBLIC_KEY and settings.WEBPUSH_VAPID_PRIVATE_KEY)


def public_key():
    return settings.WEBPUSH_VAPID_PUBLIC_KEY if is_configured() else ""


def generate_vapid_keys():
    """Returns (public_key, private_key), both base64url, in the format browsers and settings use."""
    key = ec.generate_private_key(ec.SECP256R1())
    private = key.private_numbers().private_value.to_bytes(32, "big")
    public = key.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    return b64url_encode(public), b64url_encode(private)


def _private_key():
    d = int.from_bytes(b64url_decode(settings.WEBPUSH_VAPID_PRIVATE_KEY), "big")
    return ec.derive_private_key(d, ec.SECP256R1())


def validate_subscription(endpoint, p256dh, auth):
    """Raises InvalidSubscription unless this is a real push-service endpoint with usable keys."""
    parts = urlsplit(endpoint or "")
    host = (parts.hostname or "").lower()
    if parts.scheme != "https" or not host:
        raise InvalidSubscription(_("Push endpoint must be an https URL."))
    if not any(host == h or (h.startswith(".") and host.endswith(h)) for h in ALLOWED_PUSH_HOSTS):
        raise InvalidSubscription(_("Unknown push service."))
    try:
        key = b64url_decode(p256dh)
        secret = b64url_decode(auth)
        ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), key)
    except (ValueError, TypeError) as exc:
        raise InvalidSubscription(_("Invalid subscription keys.")) from exc
    if len(key) != 65 or len(secret) != 16:
        raise InvalidSubscription(_("Invalid subscription keys."))


def encrypt(payload: bytes, p256dh: str, auth: str, *, salt=None, sender_key=None) -> bytes:
    """aes128gcm content encoding (RFC 8291 section 3, RFC 8188), one record.

    `salt` and `sender_key` are only passed by tests; normally both are random per message.
    """
    ua_public_bytes = b64url_decode(p256dh)
    auth_secret = b64url_decode(auth)
    ua_public = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), ua_public_bytes)
    sender_key = sender_key or ec.generate_private_key(ec.SECP256R1())
    as_public_bytes = sender_key.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint
    )
    salt = salt or os.urandom(16)
    shared = sender_key.exchange(ec.ECDH(), ua_public)

    key_info = b"WebPush: info\x00" + ua_public_bytes + as_public_bytes
    ikm = HKDF(algorithm=hashes.SHA256(), length=32, salt=auth_secret, info=key_info).derive(shared)
    cek = HKDF(algorithm=hashes.SHA256(), length=16, salt=salt, info=b"Content-Encoding: aes128gcm\x00").derive(ikm)
    nonce = HKDF(algorithm=hashes.SHA256(), length=12, salt=salt, info=b"Content-Encoding: nonce\x00").derive(ikm)

    if len(payload) > RECORD_SIZE - 16 - 1 - 86:
        raise ValueError("Push payload too large.")
    ciphertext = AESGCM(cek).encrypt(nonce, payload + b"\x02", None)  # \x02 = last record, no padding
    header = salt + RECORD_SIZE.to_bytes(4, "big") + bytes([len(as_public_bytes)]) + as_public_bytes
    return header + ciphertext


def vapid_authorization(endpoint):
    parts = urlsplit(endpoint)
    claims = {
        "aud": f"{parts.scheme}://{parts.netloc}",
        "exp": int(time.time()) + 12 * 3600,
        "sub": settings.WEBPUSH_SUBJECT,
    }
    token = jwt.encode(claims, _private_key(), algorithm="ES256")
    return f"vapid t={token}, k={settings.WEBPUSH_VAPID_PUBLIC_KEY}"


def send(subscription, payload: dict, *, ttl=24 * 3600, urgency="normal", topic=None):
    """Sends one message. Returns "sent", "dead" (subscription gone for good) or "failed"."""
    body = encrypt(json.dumps(payload, ensure_ascii=False).encode(), subscription.p256dh, subscription.auth)
    headers = {
        "Authorization": vapid_authorization(subscription.endpoint),
        "Content-Encoding": "aes128gcm",
        "Content-Type": "application/octet-stream",
        "TTL": str(ttl),
        "Urgency": urgency,
    }
    if topic:
        headers["Topic"] = topic
    try:
        resp = requests.post(subscription.endpoint, data=body, headers=headers, timeout=TIMEOUT_SECONDS)
    except requests.RequestException as exc:
        logger.warning("Web push to %s failed: %s", urlsplit(subscription.endpoint).hostname, exc)
        return "failed"
    if resp.status_code in (200, 201, 202):
        return "sent"
    if resp.status_code in (404, 410):
        return "dead"
    logger.warning("Web push rejected (%s): %s", resp.status_code, resp.text[:200])
    return "failed"
