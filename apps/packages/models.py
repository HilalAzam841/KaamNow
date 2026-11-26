from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.models import TimeStampedModel

MAX_PACKAGES = 10
MAX_INCLUDES = 8


class ServicePackage(TimeStampedModel):
    """A fixed-price job a worker offers, e.g. "AC service, Rs 2,500, 90 minutes".

    Customers book it straight away at a free time: no bidding and no haggling.
    """

    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="packages")
    category = models.ForeignKey("catalog.ServiceCategory", on_delete=models.PROTECT, related_name="packages")
    title = models.CharField(max_length=80)
    description = models.TextField(max_length=600, blank=True)
    includes = models.JSONField(default=list, blank=True, help_text="Short lines of what the price covers.")
    price = models.DecimalField(max_digits=10, decimal_places=2)
    duration_minutes = models.PositiveSmallIntegerField(
        default=60, validators=[MinValueValidator(30), MaxValueValidator(480)])
    is_active = models.BooleanField(default=True, help_text="Paused packages are not shown to customers.")
    times_booked = models.PositiveIntegerField(default=0)
    is_hidden = models.BooleanField(default=False, db_index=True, help_text="Hidden by an admin.")
    hidden_reason = models.CharField(max_length=255, blank=True)
    hidden_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                  related_name="+")

    class Meta:
        ordering = ["price", "id"]
        indexes = [models.Index(fields=["category", "is_active", "is_hidden"])]

    def __str__(self):
        return f"{self.title} by worker {self.worker_id}"
