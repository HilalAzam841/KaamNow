from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.catalog.models import ServiceCategory
from apps.jobs.models import Booking

from .models import (
    Commission,
    FeaturedListing,
    FeaturedPlan,
    LedgerEntry,
    Payment,
    PlatformSettings,
    SubscriptionPlan,
    WorkerSubscription,
)

ONLINE_METHOD_CHOICES = [(Payment.Method.JAZZCASH.value, "JazzCash"), (Payment.Method.EASYPAISA.value, "Easypaisa")]


class PaymentCreateSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all())
    method = serializers.ChoiceField(choices=Payment.Method.choices, default=Payment.Method.CASH)


class CheckoutSerializer(serializers.Serializer):
    url = serializers.URLField()
    method = serializers.CharField()
    fields = serializers.DictField(child=serializers.CharField())


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = [
            "id", "purpose", "booking", "amount", "method", "status", "reference", "failure_reason", "expires_at",
            "confirmed_at", "created_at", "updated_at",
        ]
        read_only_fields = fields


class PaymentWithCheckoutSerializer(PaymentSerializer):
    checkout = CheckoutSerializer(
        read_only=True, allow_null=True,
        help_text="For JazzCash/Easypaisa: POST these fields to `url` (e.g. in a WebView). Null for cash.",
    )

    class Meta(PaymentSerializer.Meta):
        fields = PaymentSerializer.Meta.fields + ["checkout"]
        read_only_fields = fields


class CommissionSerializer(serializers.ModelSerializer):
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)

    class Meta:
        model = Commission
        fields = [
            "id", "booking", "worker", "worker_name", "gross_amount", "rate_percent", "commission_amount",
            "worker_earning", "status", "created_at",
        ]
        read_only_fields = fields


class LedgerEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = LedgerEntry
        fields = ["id", "payment", "booking", "worker", "entry_type", "amount", "description", "created_at"]
        read_only_fields = fields


class PlatformSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlatformSettings
        fields = ["commission_percent", "emergency_fee", "emergency_enabled", "updated_at"]
        read_only_fields = ["updated_at"]


class EarningsSummarySerializer(serializers.Serializer):
    completed_jobs = serializers.IntegerField()
    gross_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    net_earnings = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_pending = serializers.DecimalField(max_digits=14, decimal_places=2)
    current_commission_percent = serializers.DecimalField(max_digits=5, decimal_places=2)
    recent = CommissionSerializer(many=True)


# --- Subscriptions -------------------------------------------------------------
class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = [
            "id", "name", "slug", "description", "price", "duration_days", "commission_percent",
            "daily_offer_limit", "benefits", "badge", "is_default", "is_active", "sort_order",
        ]
        read_only_fields = ["id"]

    def validate_benefits(self, value):
        if not isinstance(value, list) or not all(isinstance(b, str) and len(b) <= 120 for b in value):
            raise serializers.ValidationError(_("Benefits must be a list of short strings."))
        return value

    def validate(self, attrs):
        is_default = attrs.get("is_default", getattr(self.instance, "is_default", False))
        price = attrs.get("price", getattr(self.instance, "price", None))
        if is_default and price not in (None, 0) and price != 0:
            raise serializers.ValidationError({"is_default": "Only a free plan can be the default plan."})
        return attrs


class SubscribeSerializer(serializers.Serializer):
    plan = serializers.PrimaryKeyRelatedField(queryset=SubscriptionPlan.objects.filter(is_active=True))
    method = serializers.ChoiceField(choices=ONLINE_METHOD_CHOICES, required=False)


class WorkerSubscriptionSerializer(serializers.ModelSerializer):
    plan = SubscriptionPlanSerializer(read_only=True)
    payment = PaymentSerializer(read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)

    class Meta:
        model = WorkerSubscription
        fields = ["id", "worker", "worker_name", "plan", "status", "amount", "starts_at", "ends_at", "payment",
                  "created_at"]
        read_only_fields = fields


class SubscribeResponseSerializer(serializers.Serializer):
    subscription = WorkerSubscriptionSerializer()
    checkout = CheckoutSerializer(allow_null=True)


class MySubscriptionSerializer(serializers.Serializer):
    plan = SubscriptionPlanSerializer()
    subscription = WorkerSubscriptionSerializer(allow_null=True)
    offers_today = serializers.IntegerField()
    offers_remaining_today = serializers.IntegerField(allow_null=True)
    commission_percent = serializers.DecimalField(max_digits=5, decimal_places=2)


# --- Featured listings ----------------------------------------------------------
class FeaturedPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeaturedPlan
        fields = ["id", "name", "duration_days", "price", "is_active"]
        read_only_fields = ["id"]


class FeaturedPurchaseSerializer(serializers.Serializer):
    plan = serializers.PrimaryKeyRelatedField(queryset=FeaturedPlan.objects.filter(is_active=True))
    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.filter(is_active=True))
    method = serializers.ChoiceField(choices=ONLINE_METHOD_CHOICES)


class FeaturedListingSerializer(serializers.ModelSerializer):
    plan = FeaturedPlanSerializer(read_only=True)
    category_name = serializers.CharField(source="category.display_name", read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    payment = PaymentSerializer(read_only=True)

    class Meta:
        model = FeaturedListing
        fields = ["id", "worker", "worker_name", "category", "category_name", "plan", "status", "amount",
                  "starts_at", "ends_at", "payment", "created_at"]
        read_only_fields = fields


class FeaturedPurchaseResponseSerializer(serializers.Serializer):
    listing = FeaturedListingSerializer()
    checkout = CheckoutSerializer()
