from django.utils.translation import gettext as _
from decimal import Decimal

from rest_framework import serializers

from apps.accounts.serializers import PublicWorkerSerializer

from .models import Negotiation, WorkerOffer


class NegotiationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Negotiation
        fields = ["id", "party", "action", "amount", "message", "created_at"]
        read_only_fields = fields


class WorkerOfferSerializer(serializers.ModelSerializer):
    worker = PublicWorkerSerializer(read_only=True)
    negotiations = NegotiationSerializer(many=True, read_only=True)
    booking_id = serializers.SerializerMethodField()

    class Meta:
        model = WorkerOffer
        fields = [
            "id", "request", "worker", "initial_price", "current_price", "awaiting", "estimated_arrival_minutes",
            "message", "additional_info", "distance_km", "status", "negotiations", "booking_id",
            "created_at", "updated_at",
        ]
        read_only_fields = fields

    def get_booking_id(self, obj) -> int | None:
        booking = getattr(obj, "booking", None) if hasattr(obj, "booking") else None
        return booking.pk if booking else None


class OfferCreateSerializer(serializers.Serializer):
    price = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("1"))
    estimated_arrival_minutes = serializers.IntegerField(min_value=5, max_value=24 * 60)
    message = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")
    additional_info = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")


class OfferUpdateSerializer(serializers.Serializer):
    price = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("1"), required=False)
    estimated_arrival_minutes = serializers.IntegerField(min_value=5, max_value=24 * 60, required=False)
    message = serializers.CharField(max_length=500, required=False, allow_blank=True)
    additional_info = serializers.CharField(max_length=1000, required=False, allow_blank=True)

    def validate(self, attrs):
        if not attrs:
            raise serializers.ValidationError(_("Nothing to update."))
        return attrs


class NegotiateSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=["counter", "agree"], default="counter")
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("1"), required=False)
    message = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")

    def validate(self, attrs):
        if attrs["action"] == "counter" and attrs.get("amount") is None:
            raise serializers.ValidationError({"amount": _("Amount is required for a counter proposal.")})
        return attrs


class OfferRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


class OfferAcceptSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")
