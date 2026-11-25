from decimal import Decimal

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.models import TimeStampedModel
from apps.common.utils import RandomUploadPath
from apps.common.validators import validate_image_upload

LAT_VALIDATORS = [MinValueValidator(Decimal("-90")), MaxValueValidator(Decimal("90"))]
LNG_VALIDATORS = [MinValueValidator(Decimal("-180")), MaxValueValidator(Decimal("180"))]


class ServiceRequest(TimeStampedModel):
    class Status(models.TextChoices):
        OPEN = "open", "Open for offers"
        BOOKED = "booked", "Booked"
        CANCELLED = "cancelled", "Cancelled"
        EXPIRED = "expired", "Expired"

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="service_requests")
    category = models.ForeignKey("catalog.ServiceCategory", on_delete=models.PROTECT, related_name="requests")
    title = models.CharField(max_length=150)
    description = models.TextField(max_length=3000)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, validators=LAT_VALIDATORS)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, validators=LNG_VALIDATORS)
    address = models.CharField(max_length=255)
    area = models.CharField(max_length=100, blank=True, help_text="Public area name, e.g. 'DHA Phase 5'.")
    preferred_time = models.DateTimeField()
    duration_minutes = models.PositiveSmallIntegerField(
        default=120, help_text="How long the job is expected to take; the worker is booked for this window.",
    )
    budget = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    is_emergency = models.BooleanField(default=False, db_index=True)
    emergency_fee = models.DecimalField(
        max_digits=10, decimal_places=2, default=0, help_text="Locked at request creation from platform settings."
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN, db_index=True)
    invited_worker = models.ForeignKey(
        "accounts.WorkerProfile", on_delete=models.SET_NULL, null=True, blank=True, related_name="invited_requests",
        help_text="Set when the customer books one worker directly (book again). Only this worker sees the job "
                  "until it is opened to everyone.",
    )
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancel_reason = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "category"]),
            models.Index(fields=["latitude", "longitude"]),
            models.Index(fields=["customer", "status"]),
        ]

    def __str__(self):
        return f"#{self.pk} {self.title}"

    @property
    def window(self):
        """(start, end) the worker is booked for."""
        from datetime import timedelta

        return self.preferred_time, self.preferred_time + timedelta(minutes=self.duration_minutes)

    @property
    def is_open(self):
        return self.status == self.Status.OPEN


class ServiceRequestImage(TimeStampedModel):
    request = models.ForeignKey(ServiceRequest, on_delete=models.CASCADE, related_name="images")
    image = models.ImageField(upload_to=RandomUploadPath("requests"), validators=[validate_image_upload])

    class Meta:
        ordering = ["created_at"]


class Booking(TimeStampedModel):
    class Status(models.TextChoices):
        CONFIRMED = "confirmed", "Confirmed"
        ON_THE_WAY = "on_the_way", "On the way"
        ARRIVED = "arrived", "Arrived"
        IN_PROGRESS = "in_progress", "Work started"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"

    ACTIVE_STATUSES = (Status.CONFIRMED, Status.ON_THE_WAY, Status.ARRIVED, Status.IN_PROGRESS)

    # OneToOne on request + offer is the database-level guarantee that a
    # request can only ever produce one booking.
    request = models.OneToOneField(ServiceRequest, on_delete=models.PROTECT, related_name="booking")
    offer = models.OneToOneField("offers.WorkerOffer", on_delete=models.PROTECT, related_name="booking")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="customer_bookings")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.PROTECT, related_name="bookings")
    agreed_price = models.DecimalField(max_digits=10, decimal_places=2)
    emergency_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.CONFIRMED, db_index=True)

    on_the_way_at = models.DateTimeField(null=True, blank=True)
    arrived_at = models.DateTimeField(null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancelled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    cancel_reason = models.CharField(max_length=255, blank=True)

    # Completion OTP: only a keyed hash is stored, never the plaintext.
    completion_otp_hash = models.CharField(max_length=128, blank=True)
    completion_otp_expires_at = models.DateTimeField(null=True, blank=True)
    completion_otp_attempts = models.PositiveSmallIntegerField(default=0)
    completion_otp_sent_at = models.DateTimeField(null=True, blank=True)
    completed_via = models.CharField(max_length=30, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["worker", "status"]),
            models.Index(fields=["customer", "status"]),
        ]

    def __str__(self):
        return f"Booking #{self.pk} ({self.get_status_display()})"

    @property
    def is_active(self):
        return self.status in self.ACTIVE_STATUSES

    @property
    def window(self):
        return self.request.window

    @property
    def total_amount(self):
        """What the customer pays: the negotiated price plus any emergency fee."""
        return self.agreed_price + self.emergency_fee


class BookingStatusLog(models.Model):
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name="status_logs")
    from_status = models.CharField(max_length=12, blank=True)
    to_status = models.CharField(max_length=12)
    changed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+")
    note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
