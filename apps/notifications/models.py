from django.conf import settings
from django.db import models


class Notification(models.Model):
    class Type(models.TextChoices):
        NEW_REQUEST = "new_request", "New nearby request"
        NEW_OFFER = "new_offer", "New offer"
        NEGOTIATION = "negotiation", "Negotiation update"
        OFFER_ACCEPTED = "offer_accepted", "Offer accepted"
        OFFER_REJECTED = "offer_rejected", "Offer rejected"
        OFFER_CLOSED = "offer_closed", "Offer closed"
        BOOKING_STATUS = "booking_status", "Booking status"
        BOOKING_CANCELLED = "booking_cancelled", "Booking cancelled"
        BOOKING_COMPLETED = "booking_completed", "Booking completed"
        REQUEST_CANCELLED = "request_cancelled", "Request cancelled"
        PAYMENT = "payment", "Payment"
        REVIEW = "review", "Review"
        VERIFICATION = "verification", "Account verification"
        SYSTEM = "system", "System"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications")
    type = models.CharField(max_length=20, choices=Type.choices)
    title = models.CharField(max_length=150)
    body = models.CharField(max_length=500)
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["user", "is_read"])]

    def __str__(self):
        return f"{self.type} -> {self.user_id}"
