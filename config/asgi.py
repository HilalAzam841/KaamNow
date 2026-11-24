"""ASGI entrypoint: HTTP (Django) + WebSockets (Channels).

Run in production with:  daphne -b 0.0.0.0 -p 8000 config.asgi:application
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402

from apps.chat.middleware import JWTAuthMiddleware  # noqa: E402
from apps.chat.origin import ClientOriginValidator  # noqa: E402
from apps.chat.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": ClientOriginValidator(JWTAuthMiddleware(URLRouter(websocket_urlpatterns))),
    }
)
