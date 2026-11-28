from rest_framework import serializers

from . import services
from .models import GuaranteeClaim


class GuaranteeClaimSerializer(serializers.ModelSerializer):
    booking_title = serializers.CharField(source="booking.request.title", read_only=True)
    customer_name = serializers.SerializerMethodField()
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    can_escalate = serializers.SerializerMethodField(
        help_text="The customer can send the claim to the KaamNow team now.")
    complaint_id = serializers.IntegerField(source="complaint.id", read_only=True, allow_null=True, default=None)

    class Meta:
        model = GuaranteeClaim
        fields = ["id", "booking", "booking_title", "customer_name", "worker_name", "problem", "status",
                  "redo_time", "worker_note", "respond_by", "accepted_at", "redo_done_at", "closed_at",
                  "can_escalate", "complaint_id", "created_at"]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        """The customer's first name only."""
        return (obj.customer.full_name or "").split(" ")[0]

    def get_can_escalate(self, obj) -> bool:
        return services.can_escalate(obj)


class MakeClaimSerializer(serializers.Serializer):
    problem = serializers.CharField(max_length=1000, help_text="What went wrong again (at least 10 characters).")


class AcceptClaimSerializer(serializers.Serializer):
    redo_time = serializers.DateTimeField(help_text="When you will come back, within the next 14 days.")
    note = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


class DeclineClaimSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=500, help_text="Why (at least 10 characters). The customer sees it.")


class EscalateClaimSerializer(serializers.Serializer):
    details = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")
