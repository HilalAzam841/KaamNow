"""WebSocket consumer for a booking: real-time chat and live worker location.

Connect:  ws/bookings/<booking_id>/?token=<JWT access token>

Client -> server messages (JSON):
  {"type": "chat.message", "body": "On my way"}
  {"type": "chat.read"}
  {"type": "location.update", "latitude": 31.51, "longitude": 74.34, "speed_kmh": 30}   (worker only)
  {"type": "ping"}

Server -> client events:
  {"type": "chat.message", "data": {...}}
  {"type": "chat.read", "data": {...}}
  {"type": "location.update", "data": {...}}
  {"type": "booking.status", "data": {...}}
  {"type": "error", "message": "..."}
  {"type": "pong"}

Close codes: 4401 not authenticated, 4404 booking not found / not a participant.
"""

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from rest_framework.exceptions import APIException

from apps.common.realtime import booking_group


class BookingConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        user = self.scope.get("user")
        if user is None or not user.is_authenticated:
            await self.close(code=4401)
            return
        self.booking_id = int(self.scope["url_route"]["kwargs"]["booking_id"])
        if not await self._is_participant(user):
            await self.close(code=4404)
            return
        self.group = booking_group(self.booking_id)
        await self.channel_layer.group_add(self.group, self.channel_name)
        await self.accept()

    async def disconnect(self, code):
        if hasattr(self, "group"):
            await self.channel_layer.group_discard(self.group, self.channel_name)

    async def receive_json(self, content, **kwargs):
        kind = content.get("type") if isinstance(content, dict) else None
        try:
            if kind == "ping":
                await self.send_json({"type": "pong"})
            elif kind == "chat.message":
                await self._send_message(content.get("body", ""))
            elif kind == "chat.read":
                await self._mark_read()
            elif kind == "location.update":
                await self._record_location(content)
            else:
                await self.send_json({"type": "error", "message": "Unknown message type."})
        except APIException as exc:
            await self.send_json({"type": "error", "message": str(exc.detail)})
        except (TypeError, ValueError, ArithmeticError):
            await self.send_json({"type": "error", "message": "Invalid message."})

    async def booking_event(self, event):
        await self.send_json({"type": event["event"], "data": event["data"]})

    # --- database helpers -------------------------------------------------
    def _booking(self):
        from apps.jobs.models import Booking

        return Booking.objects.select_related("worker__user", "customer", "request").get(pk=self.booking_id)

    @database_sync_to_async
    def _is_participant(self, user):
        from apps.jobs.models import Booking

        return Booking.objects.filter(pk=self.booking_id).filter(
            customer_id=user.pk
        ).exists() or Booking.objects.filter(pk=self.booking_id, worker__user_id=user.pk).exists()

    @database_sync_to_async
    def _send_message(self, body):
        from .services import send_message

        send_message(self._booking(), self.scope["user"], body)

    @database_sync_to_async
    def _mark_read(self):
        from .services import mark_read

        mark_read(self._booking(), self.scope["user"])

    @database_sync_to_async
    def _record_location(self, content):
        from apps.tracking.services import record_location

        record_location(
            self._booking(), self.scope["user"], content["latitude"], content["longitude"],
            accuracy_m=content.get("accuracy_m"), heading=content.get("heading"), speed_kmh=content.get("speed_kmh"),
        )
