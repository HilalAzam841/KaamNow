from decimal import Decimal

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class BookingLocation(models.Model):
    """A GPS point shared by the assigned worker during an active booking."""

    booking = models.ForeignKey("jobs.Booking", on_delete=models.CASCADE, related_name="locations")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="locations")
    latitude = models.DecimalField(
        max_digits=9, decimal_places=6, validators=[MinValueValidator(Decimal("-90")), MaxValueValidator(Decimal("90"))]
    )
    longitude = models.DecimalField(
        max_digits=9, decimal_places=6,
        validators=[MinValueValidator(Decimal("-180")), MaxValueValidator(Decimal("180"))],
    )
    accuracy_m = models.DecimalField(max_digits=7, decimal_places=2, null=True, blank=True)
    heading = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    speed_kmh = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    recorded_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-recorded_at", "-id"]
        indexes = [models.Index(fields=["booking", "-recorded_at"])]

    def __str__(self):
        return f"{self.latitude},{self.longitude} for booking #{self.booking_id}"
