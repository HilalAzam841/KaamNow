from datetime import timedelta
from decimal import Decimal

from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.accounts.models import WorkerProfile
from apps.catalog.models import ServiceCategory

from .models import MAX_INCLUDES, ServicePackage


class PackageWorkerSerializer(serializers.ModelSerializer):
    """The worker on a package card: public details only."""

    full_name = serializers.CharField(source="user.full_name", read_only=True)

    class Meta:
        model = WorkerProfile
        fields = ["id", "full_name", "profile_picture", "average_rating", "rating_count", "completed_jobs_count",
                  "level"]
        read_only_fields = fields


class PackageSerializer(serializers.ModelSerializer):
    """A package as customers see it."""

    category_name = serializers.CharField(source="category.display_name", read_only=True)
    worker = PackageWorkerSerializer(read_only=True)

    class Meta:
        model = ServicePackage
        fields = ["id", "title", "description", "includes", "price", "duration_minutes", "category", "category_name",
                  "times_booked", "worker"]
        read_only_fields = fields


class MyPackageSerializer(serializers.ModelSerializer):
    """A package as its worker sees and edits it."""

    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.all())
    category_name = serializers.CharField(source="category.display_name", read_only=True)
    includes = serializers.ListField(child=serializers.CharField(max_length=80, allow_blank=True), required=False,
                                     max_length=MAX_INCLUDES)
    price = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("1"))
    duration_minutes = serializers.IntegerField(min_value=30, max_value=480, required=False)

    class Meta:
        model = ServicePackage
        fields = ["id", "title", "description", "includes", "price", "duration_minutes", "category", "category_name",
                  "is_active", "times_booked", "is_hidden", "hidden_reason", "created_at", "updated_at"]
        read_only_fields = ["id", "category_name", "times_booked", "is_hidden", "hidden_reason", "created_at",
                            "updated_at"]

    def validate_title(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError(_("Title is too short."))
        return value

    def validate_description(self, value):
        return value.strip()


class BookPackageSerializer(serializers.Serializer):
    preferred_time = serializers.DateTimeField(help_text="Start time. Pick a free slot from workers/{id}/slots/.")
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90, required=False)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180,
                                         required=False)
    address = serializers.CharField(max_length=255, required=False)
    area = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    saved_address = serializers.IntegerField(
        required=False, help_text="One of your saved addresses. Fills latitude, longitude, address and area.")
    notes = serializers.CharField(max_length=500, required=False, allow_blank=True, default="",
                                  help_text="Anything the worker should know, e.g. gate code or AC brand.")

    def validate_preferred_time(self, value):
        if value < timezone.now() - timedelta(minutes=5):
            raise serializers.ValidationError(_("Preferred time cannot be in the past."))
        if value > timezone.now() + timedelta(days=60):
            raise serializers.ValidationError(_("Preferred time must be within the next 60 days."))
        return value

    def validate(self, attrs):
        saved_id = attrs.pop("saved_address", None)
        if saved_id is not None:
            from apps.addresses.models import SavedAddress

            request = self.context.get("request")
            saved = SavedAddress.objects.filter(pk=saved_id, user=getattr(request, "user", None)).first()
            if saved is None:
                raise serializers.ValidationError({"saved_address": _("This saved address was not found.")})
            attrs.update(latitude=saved.latitude, longitude=saved.longitude, address=saved.address)
            if not attrs.get("area"):
                attrs["area"] = saved.area
        missing = {k: _("This field is required.") for k in ("latitude", "longitude", "address") if not attrs.get(k)}
        if missing:
            raise serializers.ValidationError(missing)
        attrs["notes"] = attrs.get("notes", "").strip()
        return attrs


class AdminPackageSerializer(serializers.ModelSerializer):
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)
    hidden_by_name = serializers.CharField(source="hidden_by.full_name", read_only=True, default=None)

    class Meta:
        model = ServicePackage
        fields = ["id", "worker", "worker_name", "title", "description", "includes", "price", "duration_minutes",
                  "category", "category_name", "is_active", "times_booked", "is_hidden", "hidden_reason",
                  "hidden_by_name", "created_at", "updated_at"]
        read_only_fields = fields

