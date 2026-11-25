from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.jobs.models import Booking

from .models import CreditEntry, PromoCode


class PromoCheckSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all())
    promo_code = serializers.CharField(max_length=30, required=False, allow_blank=True, default="")
    use_credit = serializers.BooleanField(default=False)


class QuoteSerializer(serializers.Serializer):
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    promo_code = serializers.CharField()
    promo_description = serializers.CharField()
    promo_discount = serializers.DecimalField(max_digits=12, decimal_places=2)
    credit_balance = serializers.DecimalField(max_digits=12, decimal_places=2)
    credit_used = serializers.DecimalField(max_digits=12, decimal_places=2)
    discount = serializers.DecimalField(max_digits=12, decimal_places=2)
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, help_text="What the customer pays.")
    max_discount = serializers.DecimalField(max_digits=12, decimal_places=2)


class CreditEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = CreditEntry
        fields = ["id", "amount", "kind", "note", "payment", "created_at"]
        read_only_fields = fields


class ReferralSummarySerializer(serializers.Serializer):
    code = serializers.CharField()
    invite_link = serializers.CharField()
    credit_balance = serializers.DecimalField(max_digits=12, decimal_places=2)
    invited = serializers.IntegerField()
    rewarded = serializers.IntegerField()
    rewards_earned = serializers.DecimalField(max_digits=12, decimal_places=2)
    referral_reward = serializers.DecimalField(max_digits=10, decimal_places=2)
    welcome_credit = serializers.DecimalField(max_digits=10, decimal_places=2)
    min_booking = serializers.DecimalField(max_digits=10, decimal_places=2)
    credit_history = CreditEntrySerializer(many=True)


class AdminPromoCodeSerializer(serializers.ModelSerializer):
    uses = serializers.IntegerField(read_only=True, default=0)
    discount_given = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True, default=0)
    category_name = serializers.CharField(source="category.name", read_only=True, default=None)

    class Meta:
        model = PromoCode
        fields = [
            "id", "code", "description", "kind", "value", "max_discount", "min_order", "category", "category_name",
            "starts_at", "ends_at", "max_uses", "max_uses_per_user", "first_booking_only", "is_active", "uses",
            "discount_given", "created_at",
        ]
        read_only_fields = ["id", "uses", "discount_given", "category_name", "created_at"]

    def validate_code(self, value):
        value = value.strip().upper()
        if not value.replace("-", "").isalnum() or len(value) < 3:
            raise serializers.ValidationError(_("Use 3 to 30 letters, digits or dashes."))
        qs = PromoCode.objects.filter(code=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError(_("A promo code with this name already exists."))
        return value

    def validate(self, attrs):
        kind = attrs.get("kind", getattr(self.instance, "kind", None))
        value = attrs.get("value", getattr(self.instance, "value", None))
        if kind == PromoCode.Kind.PERCENT and value is not None and value > 100:
            raise serializers.ValidationError({"value": _("A percent code can take at most 100% off.")})
        starts = attrs.get("starts_at", getattr(self.instance, "starts_at", None))
        ends = attrs.get("ends_at", getattr(self.instance, "ends_at", None))
        if starts and ends and ends <= starts:
            raise serializers.ValidationError({"ends_at": _("The end must be after the start.")})
        if self.instance is None and ends and ends < timezone.now():
            raise serializers.ValidationError({"ends_at": _("The end is in the past.")})
        if attrs.get("max_uses_per_user") == 0:
            raise serializers.ValidationError({"max_uses_per_user": _("Allow at least one use.")})
        return attrs
