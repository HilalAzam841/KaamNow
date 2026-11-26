from rest_framework import serializers

from .models import CancellationFee


class CancellationQuoteSerializer(serializers.Serializer):
    fee = serializers.DecimalField(max_digits=10, decimal_places=2, help_text="What cancelling now costs (0: free).")
    reason = serializers.ChoiceField(choices=CancellationFee.Reason.choices, allow_null=True)
    free_until = serializers.DateTimeField(allow_null=True, help_text="Cancelling is free until this time.")
    fee_after = serializers.DecimalField(max_digits=10, decimal_places=2, allow_null=True,
                                         help_text="The fee after free_until.")


class CancellationFeeSerializer(serializers.ModelSerializer):
    booking_title = serializers.CharField(source="booking.request.title", read_only=True)
    payment_id = serializers.IntegerField(source="payment.id", read_only=True, allow_null=True, default=None)

    class Meta:
        model = CancellationFee
        fields = ["id", "booking", "booking_title", "reason", "amount", "worker_share", "status", "payment_id",
                  "paid_at", "waived_reason", "created_at"]
        read_only_fields = fields


class AdminCancellationFeeSerializer(CancellationFeeSerializer):
    customer_name = serializers.CharField(source="customer.full_name", read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    commission_percent = serializers.DecimalField(max_digits=5, decimal_places=2, read_only=True)

    class Meta(CancellationFeeSerializer.Meta):
        fields = CancellationFeeSerializer.Meta.fields + ["customer", "customer_name", "worker", "worker_name",
                                                          "commission_percent"]
        read_only_fields = fields


class PayFeeSerializer(serializers.Serializer):
    method = serializers.ChoiceField(choices=["jazzcash", "easypaisa"])


class WaiveSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)

    def validate_reason(self, value):
        from django.utils.translation import gettext as _

        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError(_("Give a short reason."))
        return value


class RecordReceivedSerializer(serializers.Serializer):
    reference = serializers.CharField(max_length=100, required=False, allow_blank=True, default="",
                                      help_text="Receipt or transfer reference.")
