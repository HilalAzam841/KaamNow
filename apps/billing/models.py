from decimal import Decimal

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import Q

from apps.common.models import TimeStampedModel


class PlatformSettings(TimeStampedModel):
    """Singleton row holding admin-configurable business settings."""

    commission_percent = models.DecimalField(
        max_digits=5, decimal_places=2, default=Decimal("10.00"),
        validators=[MinValueValidator(Decimal("0")), MaxValueValidator(Decimal("50"))],
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        verbose_name = "platform settings"
        verbose_name_plural = "platform settings"

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def load(cls):
        obj, _ = cls.objects.get_or_create(
            pk=1, defaults={"commission_percent": Decimal(settings.KAAMNOW["DEFAULT_COMMISSION_PERCENT"])}
        )
        return obj

    def __str__(self):
        return f"Commission {self.commission_percent}%"


class Commission(TimeStampedModel):
    """Platform commission computed once, when a booking completes."""

    class Status(models.TextChoices):
        PENDING = "pending", "Pending collection"
        COLLECTED = "collected", "Collected"
        WAIVED = "waived", "Waived"

    booking = models.OneToOneField("jobs.Booking", on_delete=models.PROTECT, related_name="commission")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.PROTECT, related_name="commissions")
    gross_amount = models.DecimalField(max_digits=12, decimal_places=2)
    rate_percent = models.DecimalField(max_digits=5, decimal_places=2)
    commission_amount = models.DecimalField(max_digits=12, decimal_places=2)
    worker_earning = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(
                condition=Q(commission_amount__gte=0) & Q(worker_earning__gte=0), name="commission_non_negative"
            ),
        ]

    def __str__(self):
        return f"Commission Rs.{self.commission_amount} on booking #{self.booking_id}"


class Payment(TimeStampedModel):
    class Method(models.TextChoices):
        CASH = "cash", "Cash"
        JAZZCASH = "jazzcash", "JazzCash"
        EASYPAISA = "easypaisa", "Easypaisa"

    class Status(models.TextChoices):
        PENDING = "pending", "Awaiting confirmation"
        COMPLETED = "completed", "Completed"
        FAILED = "failed", "Failed"
        DISPUTED = "disputed", "Disputed"

    booking = models.ForeignKey("jobs.Booking", on_delete=models.PROTECT, related_name="payments")
    payer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="payments")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    method = models.CharField(max_length=10, choices=Method.choices, default=Method.CASH)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    reference = models.CharField(max_length=64, unique=True)
    gateway_transaction_id = models.CharField(max_length=100, blank=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    confirmed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            # At most one live (pending or completed) payment per booking.
            models.UniqueConstraint(
                fields=["booking"], condition=Q(status__in=["pending", "completed"]),
                name="one_live_payment_per_booking",
            ),
            models.CheckConstraint(condition=Q(amount__gt=0), name="payment_amount_positive"),
        ]

    def __str__(self):
        return f"Payment {self.reference} Rs.{self.amount} ({self.status})"


class LedgerEntry(models.Model):
    """Append-only money ledger. Every completed payment produces balanced entries."""

    class EntryType(models.TextChoices):
        CUSTOMER_PAYMENT = "customer_payment", "Customer payment"
        PLATFORM_COMMISSION = "platform_commission", "Platform commission"
        WORKER_EARNING = "worker_earning", "Worker earning"

    payment = models.ForeignKey(Payment, on_delete=models.PROTECT, related_name="ledger_entries")
    booking = models.ForeignKey("jobs.Booking", on_delete=models.PROTECT, related_name="ledger_entries")
    worker = models.ForeignKey(
        "accounts.WorkerProfile", on_delete=models.PROTECT, null=True, blank=True, related_name="ledger_entries"
    )
    entry_type = models.CharField(max_length=20, choices=EntryType.choices)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["created_at", "id"]
        verbose_name_plural = "ledger entries"
        constraints = [
            models.UniqueConstraint(fields=["payment", "entry_type"], name="unique_ledger_entry_per_payment_type"),
        ]
