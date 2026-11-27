from django.conf import settings
from rest_framework import serializers

from apps.common.validators import validate_image_upload
from apps.jobs.models import Booking

from .models import MAX_REPLY, Review, ReviewPhoto


class ReviewCreateSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all())
    rating = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")


class ReviewPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewPhoto
        fields = ["id", "image"]
        read_only_fields = fields


class ReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.SerializerMethodField()
    category_name = serializers.CharField(source="booking.request.category.display_name", read_only=True)
    photos = serializers.SerializerMethodField()
    can_reply = serializers.SerializerMethodField()

    class Meta:
        model = Review
        fields = ["id", "booking", "worker", "rating", "comment", "customer_name", "category_name", "photos",
                  "reply", "replied_at", "can_reply", "created_at"]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        # First name only for privacy.
        return obj.customer.full_name.split(" ")[0]

    def get_photos(self, obj) -> list[dict]:
        """The review's photos (id, image URL). Photos hidden by an admin are left out."""
        photos = [p for p in obj.photos.all() if not p.is_hidden]
        return ReviewPhotoSerializer(photos, many=True, context=self.context).data

    def get_can_reply(self, obj) -> bool:
        """Whether the viewer is the reviewed worker and has not replied yet."""
        request = self.context.get("request")
        user = getattr(request, "user", None)
        return bool(user and user.is_authenticated and not obj.reply and obj.is_visible
                    and obj.worker.user_id == user.pk)


class ReviewPhotoUploadSerializer(serializers.Serializer):
    image = serializers.ImageField(validators=[validate_image_upload],
                                   help_text=f"JPEG, PNG or WEBP, up to {settings.MAX_IMAGE_UPLOAD_MB} MB. "
                                             "Location and camera data are removed.")


class ReplySerializer(serializers.Serializer):
    reply = serializers.CharField(max_length=MAX_REPLY)


class AdminReviewPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewPhoto
        fields = ["id", "image", "is_hidden", "hidden_reason"]
        read_only_fields = fields


class AdminReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.full_name", read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    photos = AdminReviewPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = Review
        fields = ["id", "booking", "worker", "worker_name", "customer", "customer_name", "rating", "comment",
                  "is_visible", "photos", "reply", "replied_at", "created_at"]
        read_only_fields = fields


class ModerationReasonSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)

    def validate_reason(self, value):
        from django.utils.translation import gettext as _

        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError(_("Give a short reason."))
        return value
