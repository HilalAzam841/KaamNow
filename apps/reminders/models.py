from django.conf import settings
from django.db import models


class BookingReminder(models.Model):
    """One reminder sent for a booking. The unique pair makes sending idempotent."""

    class Kind(models.TextChoices):
        DAY = "day", "Day before"
        HOUR = "hour", "Hour before"

    booking = models.ForeignKey("jobs.Booking", on_delete=models.CASCADE, related_name="reminders")
    kind = models.CharField(max_length=4, choices=Kind.choices)
    sent_at = models.DateTimeField(auto_now_add=True)
    sms_sent = models.BooleanField(default=False)

    class Meta:
        ordering = ["-sent_at"]
        constraints = [models.UniqueConstraint(fields=["booking", "kind"], name="one_reminder_per_kind")]

    def __str__(self):
        return f"{self.get_kind_display()} reminder for booking #{self.booking_id}"


class NoShowReport(models.Model):
    """The worker did not come, or the customer was not there. The booking is cancelled."""

    class Side(models.TextChoices):
        WORKER = "worker", "Worker did not come"
        CUSTOMER = "customer", "Customer was not there"

    class Review(models.TextChoices):
        OPEN = "open", "Not reviewed"
        CONFIRMED = "confirmed", "Confirmed"
        DISMISSED = "dismissed", "Dismissed"

    booking = models.OneToOneField("jobs.Booking", on_delete=models.CASCADE, related_name="no_show")
    side = models.CharField(max_length=8, choices=Side.choices, help_text="Who did not show up.")
    reported_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    against = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="no_shows_against")
    note = models.CharField(max_length=500, blank=True)
    review = models.CharField(max_length=10, choices=Review.choices, default=Review.OPEN, db_index=True)
    admin_note = models.CharField(max_length=500, blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_side_display()} (booking #{self.booking_id})"
