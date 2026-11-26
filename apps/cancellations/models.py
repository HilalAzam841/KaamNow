from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.common.models import TimeStampedModel


class CancellationFee(TimeStampedModel):
    """What a customer owes for cancelling a booking late. Paid to the worker, less commission."""

    class Reason(models.TextChoices):
        LATE = "late", "Cancelled close to the start time"
        ON_THE_WAY = "on_the_way", "Cancelled after the worker set off"
        ARRIVED = "arrived", "Cancelled after the worker arrived"

    class Status(models.TextChoices):
        OWED = "owed", "Owed"
        PAID = "paid", "Paid"
        WAIVED = "waived", "Waived"

    booking = models.OneToOneField("jobs.Booking", on_delete=models.PROTECT, related_name="cancellation_fee")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="cancellation_fees")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.PROTECT, related_name="cancellation_fees")
    reason = models.CharField(max_length=12, choices=Reason.choices)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    commission_percent = models.DecimalField(max_digits=5, decimal_places=2)
    worker_share = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=8, choices=Status.choices, default=Status.OWED, db_index=True)
    payment = models.OneToOneField("billing.Payment", on_delete=models.PROTECT, null=True, blank=True,
                                   related_name="cancellation_fee")
    paid_at = models.DateTimeField(null=True, blank=True)
    waived_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                  related_name="+")
    waived_reason = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(condition=Q(amount__gt=0), name="cancellation_fee_positive"),
            models.CheckConstraint(condition=Q(worker_share__gte=0) & Q(worker_share__lte=models.F("amount")),
                                   name="cancellation_fee_share_within_amount"),
        ]

    def __str__(self):
        return f"Cancellation fee Rs.{self.amount} on booking {self.booking_id} ({self.status})"
