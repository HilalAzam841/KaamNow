from rest_framework import serializers

from apps.common.validators import validate_image_upload

from .models import JobPhoto


class JobPhotoSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField(help_text="Authenticated download path (send your token).")

    class Meta:
        model = JobPhoto
        fields = ["id", "booking", "kind", "caption", "file_url", "created_at"]
        read_only_fields = fields

    def get_file_url(self, obj) -> str:
        prefix = "/api/v1/admin" if self.context.get("admin") else "/api/v1"
        return f"{prefix}/bookings/{obj.booking_id}/photos/{obj.pk}/file/"


class JobPhotoCreateSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=JobPhoto.Kind.choices)
    image = serializers.ImageField(validators=[validate_image_upload])
    caption = serializers.CharField(max_length=140, required=False, allow_blank=True, default="")


class JobPhotoSummarySerializer(serializers.Serializer):
    before = serializers.IntegerField()
    after = serializers.IntegerField()
    max_per_kind = serializers.IntegerField()
    can_add_before = serializers.BooleanField()
    can_add_after = serializers.BooleanField()


