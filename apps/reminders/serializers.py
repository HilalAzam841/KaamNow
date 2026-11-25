from rest_framework import serializers

from .models import NoShowReport


class AdminNoShowSerializer(serializers.ModelSerializer):
    booking_title = serializers.CharField(source="booking.request.title", read_only=True)
    preferred_time = serializers.DateTimeField(source="booking.request.preferred_time", read_only=True)
    reported_by_name = serializers.CharField(source="reported_by.full_name", read_only=True)
    against_name = serializers.CharField(source="against.full_name", read_only=True)
    against_role = serializers.CharField(source="against.role", read_only=True)
    against_total = serializers.SerializerMethodField()

    class Meta:
        model = NoShowReport
        fields = ["id", "booking", "booking_title", "preferred_time", "side", "reported_by", "reported_by_name",
                  "against", "against_name", "against_role", "against_total", "note", "review", "admin_note",
                  "reviewed_at", "created_at"]
        read_only_fields = fields

    def get_against_total(self, obj) -> int:
        """No-shows against this person that were not dismissed, this one included."""
        return self.context.get("counts", {}).get(obj.against_id, 0)


class ReviewNoShowSerializer(serializers.Serializer):
    review = serializers.ChoiceField(choices=[NoShowReport.Review.CONFIRMED, NoShowReport.Review.DISMISSED])
    note = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")
