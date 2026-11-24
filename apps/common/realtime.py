"""Helpers for pushing events to WebSocket clients through the Channels layer."""

import json
import logging

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.core.serializers.json import DjangoJSONEncoder
from django.db import transaction

logger = logging.getLogger(__name__)


def booking_group(booking_id):
    return f"booking_{booking_id}"


def broadcast_to_booking(booking_id, event, data):
    """Sends `{type: event, data}` to every socket connected to the booking, after the DB commit."""
    payload = json.loads(json.dumps(data, cls=DjangoJSONEncoder))

    def _send():
        layer = get_channel_layer()
        if layer is None:
            return
        try:
            async_to_sync(layer.group_send)(
                booking_group(booking_id), {"type": "booking.event", "event": event, "data": payload}
            )
        except Exception:  # noqa: BLE001 - realtime is best-effort; REST remains the source of truth
            logger.exception("Realtime broadcast failed for booking %s", booking_id)

    transaction.on_commit(_send)
