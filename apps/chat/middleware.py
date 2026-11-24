"""JWT authentication for WebSocket connections.

The app connects to  wss://<host>/ws/bookings/<id>/?token=<access token>
(or sends an `Authorization: Bearer <token>` header if the client supports it).
"""

from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def _user_for_token(raw_token):
    from apps.accounts.models import User

    try:
        token = AccessToken(raw_token)
        user = User.objects.get(pk=token["user_id"])
    except (InvalidToken, TokenError, KeyError, User.DoesNotExist):
        return AnonymousUser()
    if not user.is_active or user.is_suspended:
        return AnonymousUser()
    return user


def _extract_token(scope):
    for name, value in scope.get("headers", []):
        if name == b"authorization":
            parts = value.decode().split()
            if len(parts) == 2 and parts[0].lower() == "bearer":
                return parts[1]
    query = parse_qs(scope.get("query_string", b"").decode())
    tokens = query.get("token")
    return tokens[0] if tokens else None


class JWTAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        token = _extract_token(scope)
        scope["user"] = await _user_for_token(token) if token else AnonymousUser()
        return await super().__call__(scope, receive, send)
