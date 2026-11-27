from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.common.models import TimeStampedModel

MIN_TIP = 50
MAX_MESSAGE = 200


class Tip(TimeStampedModel):
    """A thank-you a customer gives the worker after a job. The whole tip goes to the worker.

    One per booking. Paid online (the worker's wallet is credited once the gateway callback is
    verified) or in cash (the worker confirms they received it).
    """

    class Status(models.TextChoices):
        PENDING = "pending", "Waiting for payment or for the worker to confirm cash"
        PAID = "paid", "Paid"
        CANCELLED = "cancelled", "Cancelled"

    booking = models.OneToOneField("jobs.Booking", on_delete=models.PROTECT, related_name="tip")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="tips_given")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.PROTECT, related_name="tips")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    method = models.CharField(max_length=10, default="cash")
    message = models.CharField(max_length=MAX_MESSAGE, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    payment = models.OneToOneField("billing.Payment", on_delete=models.PROTECT, null=True, blank=True,
                                   related_name="tip")
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.CheckConstraint(condition=Q(amount__gt=0), name="tip_amount_positive")]

    def __str__(self):
        return f"Tip Rs.{self.amount} on booking {self.booking_id} ({self.status})"
