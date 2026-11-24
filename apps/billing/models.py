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
    emergency_fee = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal("300.00"),
        validators=[MinValueValidator(Decimal("0")), MaxValueValidator(Decimal("10000"))],
        help_text="Flat fee added to emergency (urgent) bookings. Kept by the platform.",
    )
    emergency_enabled = models.BooleanField(default=True)
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
    class Purpose(models.TextChoices):
        BOOKING = "booking", "Booking"
        SUBSCRIPTION = "subscription", "Worker subscription"
        FEATURED_LISTING = "featured_listing", "Featured listing"

    class Method(models.TextChoices):
        CASH = "cash", "Cash"
        JAZZCASH = "jazzcash", "JazzCash"
        EASYPAISA = "easypaisa", "Easypaisa"

    class Status(models.TextChoices):
        PENDING = "pending", "Awaiting confirmation"
        COMPLETED = "completed", "Completed"
        FAILED = "failed", "Failed"
        DISPUTED = "disputed", "Disputed"
        EXPIRED = "expired", "Expired"

    ONLINE_METHODS = (Method.JAZZCASH, Method.EASYPAISA)

    purpose = models.CharField(max_length=20, choices=Purpose.choices, default=Purpose.BOOKING, db_index=True)
    booking = models.ForeignKey(
        "jobs.Booking", on_delete=models.PROTECT, related_name="payments", null=True, blank=True
    )
    payer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="payments")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    method = models.CharField(max_length=10, choices=Method.choices, default=Method.CASH)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    reference = models.CharField(max_length=64, unique=True)
    gateway_transaction_id = models.CharField(max_length=100, blank=True)
    gateway_response = models.JSONField(default=dict, blank=True, help_text="Verified gateway callback data.")
    failure_reason = models.CharField(max_length=255, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
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
            models.CheckConstraint(
                condition=~Q(purpose="booking") | Q(booking__isnull=False), name="booking_payment_has_booking"
            ),
        ]

    @property
    def is_online(self):
        return self.method in self.ONLINE_METHODS

    def __str__(self):
        return f"Payment {self.reference} Rs.{self.amount} ({self.status})"


class LedgerEntry(models.Model):
    """Append-only money ledger. Every completed payment produces balanced entries."""

    class EntryType(models.TextChoices):
        CUSTOMER_PAYMENT = "customer_payment", "Customer payment"
        PLATFORM_COMMISSION = "platform_commission", "Platform commission"
        WORKER_EARNING = "worker_earning", "Worker earning"
        EMERGENCY_FEE = "emergency_fee", "Emergency fee"
        SUBSCRIPTION_REVENUE = "subscription_revenue", "Subscription revenue"
        FEATURED_REVENUE = "featured_revenue", "Featured listing revenue"

    payment = models.ForeignKey(Payment, on_delete=models.PROTECT, related_name="ledger_entries")
    booking = models.ForeignKey(
        "jobs.Booking", on_delete=models.PROTECT, related_name="ledger_entries", null=True, blank=True
    )
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


class SubscriptionPlan(TimeStampedModel):
    """Monthly worker plans with admin-configurable price, duration and benefits."""

    name = models.CharField(max_length=60, unique=True)
    slug = models.SlugField(max_length=60, unique=True)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    duration_days = models.PositiveSmallIntegerField(default=30, validators=[MinValueValidator(1)])
    # Enforced benefits
    commission_percent = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(Decimal("0")), MaxValueValidator(Decimal("50"))],
        help_text="Overrides the platform commission for subscribers. Blank = platform default.",
    )
    daily_offer_limit = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text="Max offers per day. Blank = unlimited."
    )
    # Display-only benefit bullet points for the app.
    benefits = models.JSONField(default=list, blank=True)
    badge = models.CharField(max_length=30, blank=True, help_text="e.g. 'PRO' shown on the worker card.")
    is_default = models.BooleanField(default=False, help_text="Plan applied to workers without a subscription.")
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "price"]
        constraints = [
            models.UniqueConstraint(fields=["is_default"], condition=Q(is_default=True), name="single_default_plan"),
        ]

    def __str__(self):
        return f"{self.name} (Rs. {self.price})"

    @property
    def is_free(self):
        return self.price == 0


class WorkerSubscription(TimeStampedModel):
    class Status(models.TextChoices):
        PENDING_PAYMENT = "pending_payment", "Awaiting payment"
        ACTIVE = "active", "Active"
        EXPIRED = "expired", "Expired"
        CANCELLED = "cancelled", "Cancelled"

    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="subscriptions")
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.PROTECT, related_name="subscriptions")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING_PAYMENT, db_index=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    payment = models.OneToOneField(
        Payment, on_delete=models.PROTECT, null=True, blank=True, related_name="subscription"
    )
    activated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+",
        help_text="Set when an admin activates the plan manually.",
    )

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["worker"], condition=Q(status="active"), name="one_active_subscription_per_worker"
            ),
        ]

    def __str__(self):
        return f"{self.worker} - {self.plan.name} ({self.status})"


class FeaturedPlan(TimeStampedModel):
    """Pricing for sponsored placement in a category's search results."""

    name = models.CharField(max_length=60, unique=True)
    duration_days = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    price = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("1"))])
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["duration_days"]

    def __str__(self):
        return f"{self.name} ({self.duration_days} days, Rs. {self.price})"


class FeaturedListing(TimeStampedModel):
    class Status(models.TextChoices):
        PENDING_PAYMENT = "pending_payment", "Awaiting payment"
        ACTIVE = "active", "Active"
        EXPIRED = "expired", "Expired"
        CANCELLED = "cancelled", "Cancelled"

    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="featured_listings")
    category = models.ForeignKey("catalog.ServiceCategory", on_delete=models.PROTECT, related_name="featured_listings")
    plan = models.ForeignKey(FeaturedPlan, on_delete=models.PROTECT, related_name="listings")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING_PAYMENT, db_index=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    payment = models.OneToOneField(
        Payment, on_delete=models.PROTECT, null=True, blank=True, related_name="featured_listing"
    )

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["category", "status", "ends_at"])]
        constraints = [
            models.UniqueConstraint(
                fields=["worker", "category"], condition=Q(status="active"), name="one_active_feature_per_category"
            ),
        ]

    def __str__(self):
        return f"Featured {self.worker} in {self.category} ({self.status})"
