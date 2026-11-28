from decimal import Decimal

from rest_framework import serializers

from apps.common.validators import validate_image_upload

from .models import MAX_UNIT_PRICE, JobPart


class JobPartSerializer(serializers.ModelSerializer):
    total = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    receipt_url = serializers.SerializerMethodField(help_text="Authenticated download path, or null.")

    class Meta:
        model = JobPart
        fields = ["id", "booking", "name", "quantity", "unit_price", "total", "status", "reject_reason",
                  "receipt_url", "decided_at", "created_at"]
        read_only_fields = fields

    def get_receipt_url(self, obj) -> str | None:
        if not obj.receipt:
            return None
        prefix = "/api/v1/admin" if self.context.get("admin") else "/api/v1"
        return f"{prefix}/bookings/{obj.booking_id}/parts/{obj.pk}/receipt/"


class JobPartCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=100)
    quantity = serializers.IntegerField(min_value=1, max_value=50, default=1)
    unit_price = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("1"),
                                          max_value=MAX_UNIT_PRICE)
    receipt = serializers.ImageField(required=False, validators=[validate_image_upload],
                                     help_text="Optional photo of the shop receipt.")


class RejectPartSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)


class PartsSummarySerializer(serializers.Serializer):
    approved_total = serializers.DecimalField(max_digits=12, decimal_places=2)
    pending = serializers.IntegerField()
    count = serializers.IntegerField()
    can_add = serializers.BooleanField()
    can_decide = serializers.BooleanField()
