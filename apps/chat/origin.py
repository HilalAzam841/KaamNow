"""WebSocket origin check that also accepts the browser origins allowed by CORS.

Channels' AllowedHostsOriginValidator only accepts origins whose host is in ALLOWED_HOSTS.
A Flutter web build served from another origin (e.g. https://app.kaamnow.pk talking to
https://api.kaamnow.pk, or localhost:5xxxx in development) would be rejected, so we accept
an origin if it matches ALLOWED_HOSTS *or* the CORS allow-lists. Native mobile apps send
no Origin header and are accepted, exactly as with the stock validator.
"""

import re
from urllib.parse import urlparse

from channels.security.websocket import OriginValidator
from django.conf import settings
from django.http.request import is_same_domain


def origin_allowed(origin: str | None) -> bool:
    if not origin:
        return True  # non-browser clients (mobile apps) send no Origin
    origin = origin.rstrip("/")
    if origin in getattr(settings, "CORS_ALLOWED_ORIGINS", []):
        return True
    if any(re.match(rx, origin) for rx in getattr(settings, "CORS_ALLOWED_ORIGIN_REGEXES", [])):
        return True
    host = urlparse(origin).hostname or ""
    allowed = list(settings.ALLOWED_HOSTS)
    if settings.DEBUG and not allowed:
        allowed = ["localhost", "127.0.0.1", "[::1]"]
    return any(pattern == "*" or is_same_domain(host, pattern) for pattern in allowed)


class ClientOriginValidator(OriginValidator):
    def __init__(self, application):
        super().__init__(application, allowed_origins=[])

    def valid_origin(self, parsed_origin):
        if parsed_origin is None:
            return True
        if not parsed_origin.scheme or not parsed_origin.hostname:
            return False  # a present but malformed Origin (e.g. "null") is refused
        port = f":{parsed_origin.port}" if parsed_origin.port else ""
        return origin_allowed(f"{parsed_origin.scheme}://{parsed_origin.hostname}{port}")
