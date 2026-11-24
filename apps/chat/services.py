from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError
from apps.common.realtime import broadcast_to_booking
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.notifications.services import push_only

from .models import ChatMessage


def chat_is_open(booking):
    if booking.is_active:
        return True
    if booking.status == Booking.Status.COMPLETED and booking.completed_at:
        window = timedelta(hours=settings.KAAMNOW["CHAT_OPEN_HOURS_AFTER_COMPLETION"])
        return timezone.now() <= booking.completed_at + window
    return False


def serialize_message(message):
    return {
        "id": message.pk,
        "booking": message.booking_id,
        "sender": message.sender_id,
        "body": message.body,
        "is_read": message.is_read,
        "created_at": message.created_at,
    }


@transaction.atomic
def send_message(booking, sender, body):
    if sender.pk not in (booking.customer_id, booking.worker.user_id):
        raise BusinessRuleError("You are not part of this booking.", status_code=403)
    body = (body or "").strip()
    if not body:
        raise BusinessRuleError("Message cannot be empty.")
    if len(body) > 2000:
        raise BusinessRuleError("Message is too long (max 2000 characters).")
    if not chat_is_open(booking):
        raise BusinessRuleError("Chat is closed for this booking.", status_code=http_status.HTTP_409_CONFLICT)
    message = ChatMessage.objects.create(booking=booking, sender=sender, body=body)
    broadcast_to_booking(booking.pk, "chat.message", serialize_message(message))
    recipient = booking.worker.user if sender.pk == booking.customer_id else booking.customer
    transaction.on_commit(lambda: push_only(
        recipient, Notification.Type.CHAT_MESSAGE, f"Message from {sender.full_name.split(' ')[0]}", body[:120],
        {"booking_id": booking.pk, "message_id": message.pk},
    ))
    return message


def mark_read(booking, reader):
    now = timezone.now()
    updated = ChatMessage.objects.filter(booking=booking, is_read=False).exclude(sender=reader).update(
        is_read=True, read_at=now
    )
    if updated:
        broadcast_to_booking(booking.pk, "chat.read", {"reader": reader.pk, "read_at": now})
    return updated
