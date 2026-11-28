from decimal import Decimal

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.storage import private_storage
from apps.common.utils import RandomUploadPath

MAX_PARTS = 10
MAX_UNIT_PRICE = Decimal("50000")
MAX_PARTS_TOTAL = Decimal("100000")


class JobPart(models.Model):
    """A part or material the worker bought for a job (a capacitor, a pipe, paint).

    The customer approves each one before it is added to what they pay. KaamNow takes no
    commission on parts. The receipt photo is private, like job photos.
    """

    class Status(models.TextChoices):
        PENDING = "pending", "Waiting for the customer"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    booking = models.ForeignKey("jobs.Booking", on_delete=models.CASCADE, related_name="parts")
    name = models.CharField(max_length=100)
    quantity = models.PositiveSmallIntegerField(default=1, validators=[MinValueValidator(1), MaxValueValidator(50)])
    unit_price = models.DecimalField(max_digits=10, decimal_places=2,
                                     validators=[MinValueValidator(Decimal("1")), MaxValueValidator(MAX_UNIT_PRICE)])
    receipt = models.ImageField(storage=private_storage, upload_to=RandomUploadPath("part_receipts"), blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    reject_reason = models.CharField(max_length=255, blank=True)
    added_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+")
    decided_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self):
        return f"{self.name} x{self.quantity} on booking {self.booking_id}"

    @property
    def total(self):
        return self.unit_price * self.quantity
