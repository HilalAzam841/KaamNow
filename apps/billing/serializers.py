from rest_framework import serializers

from apps.jobs.models import Booking

from .models import Commission, LedgerEntry, Payment, PlatformSettings


class PaymentCreateSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all())
    method = serializers.ChoiceField(choices=Payment.Method.choices, default=Payment.Method.CASH)


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = [
            "id", "booking", "amount", "method", "status", "reference", "confirmed_at", "created_at", "updated_at",
        ]
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
        fields = ["commission_percent", "updated_at"]
        read_only_fields = ["updated_at"]


class EarningsSummarySerializer(serializers.Serializer):
    completed_jobs = serializers.IntegerField()
    gross_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    net_earnings = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_pending = serializers.DecimalField(max_digits=14, decimal_places=2)
    recent = CommissionSerializer(many=True)
