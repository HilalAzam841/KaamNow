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
        CHAT_MESSAGE = "chat_message", "New chat message"
        SUBSCRIPTION = "subscription", "Subscription"
        FEATURED = "featured", "Featured listing"
        COMPLAINT = "complaint", "Complaint update"
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


class DeviceToken(models.Model):
    """Firebase Cloud Messaging registration token for one of the user's devices."""

    class Platform(models.TextChoices):
        ANDROID = "android", "Android"
        IOS = "ios", "iOS"
        WEB = "web", "Web"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="device_tokens")
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=10, choices=Platform.choices, default=Platform.ANDROID)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-last_seen_at"]
        indexes = [models.Index(fields=["user", "is_active"])]

    def __str__(self):
        return f"{self.platform} token for user {self.user_id}"


class WebPushSubscription(models.Model):
    """A browser's Web Push subscription (standard web push, no Firebase needed).

    The endpoint is a URL at the browser vendor's push service; p256dh and auth are the
    browser's keys used to encrypt each message so only that browser can read it.
    """

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="web_push_subscriptions")
    endpoint = models.URLField(max_length=1000, unique=True)
    p256dh = models.CharField(max_length=100)
    auth = models.CharField(max_length=50)
    user_agent = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-last_seen_at"]
        indexes = [models.Index(fields=["user", "is_active"])]

    def __str__(self):
        return f"web push for user {self.user_id}"
