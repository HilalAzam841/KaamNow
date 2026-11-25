from django.conf import settings
from django.db import models

from apps.common.validators import validate_pk_phone


class EmergencyContact(models.Model):
    """Someone a user trusts (family, a friend) who is texted when they press SOS. Up to 3 each."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="emergency_contacts")
    name = models.CharField(max_length=60)
    phone = models.CharField(max_length=13, validators=[validate_pk_phone])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        constraints = [models.UniqueConstraint(fields=["user", "phone"], name="one_contact_per_phone")]

    def __str__(self):
        return f"{self.name} ({self.user_id})"


class SosAlert(models.Model):
    """A call for help raised by the customer or the worker during a job. Admins handle it."""

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        ACKNOWLEDGED = "acknowledged", "Someone is on it"
        RESOLVED = "resolved", "Resolved"

    class Role(models.TextChoices):
        CUSTOMER = "customer", "Customer"
        WORKER = "worker", "Worker"

    booking = models.ForeignKey("jobs.Booking", on_delete=models.PROTECT, related_name="sos_alerts")
    raised_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="sos_alerts")
    role = models.CharField(max_length=10, choices=Role.choices)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    note = models.CharField(max_length=500, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.OPEN, db_index=True)
    contacts_texted = models.PositiveSmallIntegerField(default=0)
    handled_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="+")
    handled_at = models.DateTimeField(null=True, blank=True)
    admin_note = models.CharField(max_length=1000, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"SOS #{self.pk} on booking #{self.booking_id}"


class TripShare(models.Model):
    """A private link that lets family follow a job: status and the worker's position while on the way.

    Only a hash of the token is stored, so the link cannot be read back from the database.
    """

    booking = models.ForeignKey("jobs.Booking", on_delete=models.CASCADE, related_name="trip_shares")
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    token_hash = models.CharField(max_length=64, unique=True)
    expires_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
