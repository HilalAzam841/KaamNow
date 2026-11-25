from django.conf import settings
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.catalog.models import ServiceCategory
from apps.common.validators import validate_image_upload
from apps.jobs.models import Booking

from .models import PortfolioPhoto


class PortfolioPhotoSerializer(serializers.ModelSerializer):
    """A photo as everyone sees it."""

    category_name = serializers.CharField(source="category.display_name", read_only=True, default=None)
    from_job = serializers.SerializerMethodField()

    class Meta:
        model = PortfolioPhoto
        fields = ["id", "image", "caption", "category", "category_name", "from_job", "created_at"]
        read_only_fields = fields

    def get_from_job(self, obj) -> bool:
        """True when the photo is linked to a job the worker finished on KaamNow."""
        return obj.booking_id is not None


class MyPortfolioPhotoSerializer(PortfolioPhotoSerializer):
    """The worker's own view, with whether an admin hid it and why."""

    class Meta(PortfolioPhotoSerializer.Meta):
        fields = PortfolioPhotoSerializer.Meta.fields + ["booking", "position", "is_hidden", "hidden_reason"]
        read_only_fields = fields


class PortfolioUploadSerializer(serializers.Serializer):
    image = serializers.ImageField(validators=[validate_image_upload],
                                   help_text=f"JPEG, PNG or WEBP, up to {settings.MAX_IMAGE_UPLOAD_MB} MB. "
                                             "Location and camera data are removed.")
    caption = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.all(), required=False,
                                                  allow_null=True, default=None)
    booking = serializers.PrimaryKeyRelatedField(
        queryset=Booking.objects.select_related("request__category"), required=False, allow_null=True,
        default=None, help_text="A job you finished on KaamNow that this photo is from.")


class PortfolioUpdateSerializer(serializers.Serializer):
    caption = serializers.CharField(max_length=150, required=False, allow_blank=True)
    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.all(), required=False,
                                                  allow_null=True)


class ReorderSerializer(serializers.Serializer):
    ids = serializers.ListField(child=serializers.IntegerField(), max_length=50)


class AdminPortfolioPhotoSerializer(MyPortfolioPhotoSerializer):
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    worker = serializers.IntegerField(source="worker_id", read_only=True)
    hidden_by_name = serializers.CharField(source="hidden_by.full_name", read_only=True, default=None)

    class Meta(MyPortfolioPhotoSerializer.Meta):
        fields = MyPortfolioPhotoSerializer.Meta.fields + ["worker", "worker_name", "hidden_by_name", "hidden_at"]
        read_only_fields = fields


class HideSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)

    def validate_reason(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError(_("Say why, so the worker knows."))
        return value
