from django.conf import settings
from django.db import models


class ChatMessage(models.Model):
    """A message between the customer and the worker of one booking."""

    booking = models.ForeignKey("jobs.Booking", on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sent_messages")
    body = models.TextField(max_length=2000)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["created_at", "id"]
        indexes = [models.Index(fields=["booking", "created_at"]), models.Index(fields=["booking", "is_read"])]

    def __str__(self):
        return f"Message #{self.pk} on booking #{self.booking_id}"
