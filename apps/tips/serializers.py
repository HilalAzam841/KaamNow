from rest_framework import serializers

from .models import MAX_MESSAGE, Tip


class GiveTipSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=10, decimal_places=2,
                                      help_text="Checked against the minimum and tip_max_amount on the server.")
    method = serializers.ChoiceField(choices=["cash", "jazzcash", "easypaisa"])
    message = serializers.CharField(max_length=MAX_MESSAGE, required=False, allow_blank=True, default="",
                                    help_text="An optional thank-you note shown to the worker.")


class TipSerializer(serializers.ModelSerializer):
    booking_title = serializers.CharField(source="booking.request.title", read_only=True)
    customer_name = serializers.SerializerMethodField()
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    payment_id = serializers.IntegerField(source="payment.id", read_only=True, allow_null=True, default=None)

    class Meta:
        model = Tip
        fields = ["id", "booking", "booking_title", "customer_name", "worker_name", "amount", "method", "message",
                  "status", "payment_id", "paid_at", "created_at"]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        """The customer's first name only."""
        return (obj.customer.full_name or "").split(" ")[0]


class TipWithCheckoutSerializer(serializers.Serializer):
    tip = TipSerializer()
    checkout = serializers.JSONField(allow_null=True, help_text="Gateway form to open for online tips, else null.")


class TipSummarySerializer(serializers.Serializer):
    count = serializers.IntegerField(help_text="Paid tips received.")
    total = serializers.DecimalField(max_digits=12, decimal_places=2)


class AdminTipSerializer(TipSerializer):
    customer_name = serializers.CharField(source="customer.full_name", read_only=True)

    class Meta(TipSerializer.Meta):
        fields = TipSerializer.Meta.fields + ["customer", "worker"]
        read_only_fields = fields
