"""Promo codes, referrals and customer credit.

Discounts are paid by KaamNow: the customer pays less, the worker's earning does not change.
"""

import secrets
from decimal import Decimal

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import IntegrityError, models, transaction
from django.db.models import Q, Sum

from apps.common.models import TimeStampedModel

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O or 1/I


class PromoCode(TimeStampedModel):
    class Kind(models.TextChoices):
        PERCENT = "percent", "Percent off"
        FIXED = "fixed", "Fixed amount off"

    code = models.CharField(max_length=30, unique=True, help_text="Stored in capitals; customers can type any case.")
    description = models.CharField(max_length=200, blank=True, help_text="Shown to customers, e.g. 'Eid offer'.")
    kind = models.CharField(max_length=10, choices=Kind.choices)
    value = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))],
                                help_text="Percent (1-100) or rupees.")
    max_discount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True,
                                       help_text="Upper limit in rupees for percent codes.")
    min_order = models.DecimalField(max_digits=10, decimal_places=2, default=0,
                                    help_text="Smallest booking total the code works on.")
    category = models.ForeignKey("catalog.ServiceCategory", on_delete=models.PROTECT, null=True, blank=True,
                                 related_name="+", help_text="Only for this service, if set.")
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    max_uses = models.PositiveIntegerField(null=True, blank=True, help_text="Total uses for everyone. Empty: no limit.")
    max_uses_per_user = models.PositiveSmallIntegerField(default=1)
    first_booking_only = models.BooleanField(default=False, help_text="Only for customers who have never paid a booking.")
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="+")

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(condition=~Q(kind="percent") | Q(value__lte=100), name="promo_percent_max_100"),
            models.CheckConstraint(condition=Q(code=models.functions.Upper("code")), name="promo_code_upper"),
        ]

    def __str__(self):
        return self.code


class PromoRedemption(TimeStampedModel):
    """A promo code used on a payment. Pending while the payment is open; counts as used then too,
    so a code with one use left cannot be spent twice at the same time."""

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        APPLIED = "applied", "Applied"
        RELEASED = "released", "Released"

    promo = models.ForeignKey(PromoCode, on_delete=models.PROTECT, related_name="redemptions")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="promo_redemptions")
    payment = models.OneToOneField("billing.Payment", on_delete=models.PROTECT, related_name="promo_redemption")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)

    class Meta:
        ordering = ["-created_at"]


class ReferralCode(models.Model):
    """Every user's own invite code, made the first time they open the invite screen."""

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="referral_code")
    code = models.CharField(max_length=12, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @classmethod
    def for_user(cls, user):
        existing = cls.objects.filter(user=user).first()
        if existing:
            return existing
        for _attempt in range(10):
            code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(7))
            try:
                with transaction.atomic():
                    return cls.objects.create(user=user, code=code)
            except IntegrityError:
                existing = cls.objects.filter(user=user).first()
                if existing:
                    return existing
        raise RuntimeError("Could not generate a referral code.")


class Referral(TimeStampedModel):
    """A new customer who signed up with someone's code. The inviter is rewarded once the new
    customer's first booking is paid."""

    class Status(models.TextChoices):
        PENDING = "pending", "Waiting for first paid booking"
        REWARDED = "rewarded", "Rewarded"

    referrer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="referrals_made")
    referee = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="referred_by")
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    referrer_reward = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    welcome_credit = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    rewarded_payment = models.OneToOneField("billing.Payment", on_delete=models.PROTECT, null=True, blank=True,
                                            related_name="+")
    rewarded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(condition=~Q(referrer=models.F("referee")), name="referral_not_self"),
        ]


class CreditEntry(TimeStampedModel):
    """Customer credit: rupees off future bookings. The balance is the sum of the entries."""

    class Kind(models.TextChoices):
        WELCOME = "welcome", "Welcome credit"
        REFERRAL = "referral", "Invite reward"
        SPENT = "spent", "Used on a booking"
        RETURNED = "returned", "Returned (payment did not go through)"
        ADMIN = "admin", "Added by KaamNow"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="credit_entries")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    kind = models.CharField(max_length=10, choices=Kind.choices)
    payment = models.ForeignKey("billing.Payment", on_delete=models.PROTECT, null=True, blank=True,
                                related_name="credit_entries")
    referral = models.ForeignKey(Referral, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    note = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.CheckConstraint(condition=~Q(amount=0), name="credit_entry_not_zero")]

    @classmethod
    def balance(cls, user):
        from decimal import Decimal

        return cls.objects.filter(user=user).aggregate(s=Sum("amount"))["s"] or Decimal("0.00")
