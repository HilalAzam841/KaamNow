from rest_framework import serializers

from apps.jobs.models import Booking

from .models import Complaint


class ComplaintCreateSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all(), required=False, allow_null=True)
    category = serializers.ChoiceField(choices=Complaint.Category.choices)
    subject = serializers.CharField(min_length=5, max_length=150)
    description = serializers.CharField(min_length=20, max_length=3000)


class ComplaintSerializer(serializers.ModelSerializer):
    class Meta:
        model = Complaint
        fields = ["id", "booking", "category", "subject", "description", "status", "resolution", "resolved_at",
                  "created_at", "updated_at"]
        read_only_fields = fields


class AdminComplaintSerializer(ComplaintSerializer):
    raised_by_name = serializers.CharField(source="raised_by.full_name", read_only=True)
    raised_by_role = serializers.CharField(source="raised_by.role", read_only=True)
    against_user_name = serializers.CharField(source="against_user.full_name", default=None, read_only=True)

    class Meta(ComplaintSerializer.Meta):
        fields = ComplaintSerializer.Meta.fields + ["raised_by", "raised_by_name", "raised_by_role", "against_user",
                                                    "against_user_name", "resolved_by"]
        read_only_fields = fields


STATUS_CHANGE_CHOICES = [
    (Complaint.Status.IN_REVIEW.value, "In review"),
    (Complaint.Status.RESOLVED.value, "Resolved"),
    (Complaint.Status.REJECTED.value, "Rejected"),
]


class ComplaintStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=STATUS_CHANGE_CHOICES)
    resolution = serializers.CharField(max_length=3000, required=False, allow_blank=True, default="")
