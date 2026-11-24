from django.utils.translation import gettext as _
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings
from django.utils import timezone
from rest_framework import serializers

from apps.accounts.serializers import PublicWorkerSerializer
from apps.catalog.models import ServiceCategory
from apps.common.validators import validate_image_upload

from .models import Booking, BookingStatusLog, ServiceRequest, ServiceRequestImage


class ServiceRequestImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceRequestImage
        fields = ["id", "image", "created_at"]


class ServiceRequestCreateSerializer(serializers.ModelSerializer):
    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.filter(is_active=True))
    images = serializers.ListField(
        child=serializers.ImageField(validators=[validate_image_upload]), required=False, write_only=True,
        max_length=settings.MAX_REQUEST_IMAGES,
    )
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180)

    class Meta:
        model = ServiceRequest
        fields = [
            "id", "category", "title", "description", "latitude", "longitude", "address", "area",
            "preferred_time", "budget", "is_emergency", "images",
        ]
        read_only_fields = ["id"]
        extra_kwargs = {"budget": {"min_value": Decimal("0")}}

    def validate_preferred_time(self, value):
        if value < timezone.now() - timedelta(minutes=5):
            raise serializers.ValidationError(_("Preferred time cannot be in the past."))
        if value > timezone.now() + timedelta(days=60):
            raise serializers.ValidationError(_("Preferred time must be within the next 60 days."))
        return value

    def validate_title(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError(_("Title is too short."))
        return value

    def validate_description(self, value):
        value = value.strip()
        if len(value) < 10:
            raise serializers.ValidationError(_("Please describe the problem in at least 10 characters."))
        return value


class ServiceRequestUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceRequest
        fields = ["title", "description", "address", "area", "preferred_time", "budget"]

    validate_preferred_time = ServiceRequestCreateSerializer.validate_preferred_time
    validate_title = ServiceRequestCreateSerializer.validate_title
    validate_description = ServiceRequestCreateSerializer.validate_description


class ServiceRequestSerializer(serializers.ModelSerializer):
    """Full view for the request owner and admins."""

    category_name = serializers.CharField(source="category.display_name", read_only=True)
    images = ServiceRequestImageSerializer(many=True, read_only=True)
    offers_count = serializers.SerializerMethodField()
    booking_id = serializers.SerializerMethodField()
    matched_workers_count = serializers.SerializerMethodField()

    class Meta:
        model = ServiceRequest
        fields = [
            "id", "category", "category_name", "title", "description", "latitude", "longitude", "address", "area",
            "preferred_time", "budget", "is_emergency", "emergency_fee", "status", "images", "offers_count",
            "booking_id", "matched_workers_count",
            "cancel_reason", "cancelled_at", "created_at", "updated_at",
        ]
        read_only_fields = fields

    def get_offers_count(self, obj) -> int:
        return obj.offers.count()

    def get_booking_id(self, obj) -> int | None:
        booking = getattr(obj, "booking", None) if hasattr(obj, "booking") else None
        return booking.pk if booking else None

    def get_matched_workers_count(self, obj) -> int | None:
        return getattr(obj, "matched_workers_count", None)


def _approx(value):
    # ~1.1 km precision: enough to judge distance, not enough to find a house.
    return Decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


class ServiceRequestForWorkerSerializer(serializers.ModelSerializer):
    """What a worker sees before being booked: no address, phone or exact location."""

    category_name = serializers.CharField(source="category.display_name", read_only=True)
    customer_name = serializers.SerializerMethodField()
    approx_latitude = serializers.SerializerMethodField()
    approx_longitude = serializers.SerializerMethodField()
    distance_km = serializers.SerializerMethodField()
    images = ServiceRequestImageSerializer(many=True, read_only=True)
    my_offer_id = serializers.SerializerMethodField()

    class Meta:
        model = ServiceRequest
        fields = [
            "id", "category", "category_name", "title", "description", "area", "approx_latitude",
            "approx_longitude", "distance_km", "preferred_time", "budget", "is_emergency", "emergency_fee", "status",
            "images", "customer_name",
            "my_offer_id", "created_at",
        ]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        return obj.customer.full_name.split(" ")[0]

    def get_approx_latitude(self, obj) -> str:
        return str(_approx(obj.latitude))

    def get_approx_longitude(self, obj) -> str:
        return str(_approx(obj.longitude))

    def get_distance_km(self, obj) -> float | None:
        if hasattr(obj, "distance_km"):
            return obj.distance_km
        worker = self.context.get("worker")
        if worker is None:
            return None
        from .services import worker_distance_to_request

        return worker_distance_to_request(worker, obj)

    def get_my_offer_id(self, obj) -> int | None:
        worker = self.context.get("worker")
        if worker is None:
            return None
        offer = obj.offers.filter(worker=worker).only("id").first()
        return offer.pk if offer else None


class CancelSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")


class BookingCancelSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)


STATUS_CHANGE_CHOICES = [
    (Booking.Status.ON_THE_WAY.value, "On the way"),
    (Booking.Status.ARRIVED.value, "Arrived"),
    (Booking.Status.IN_PROGRESS.value, "Work started"),
]


class BookingStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=STATUS_CHANGE_CHOICES)
    note = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")


class BookingCompleteSerializer(serializers.Serializer):
    otp = serializers.RegexField(r"^\d{4,8}$", required=False, help_text="Required when the worker completes.")
    confirm = serializers.BooleanField(required=False, default=False, help_text="Customer in-app confirmation.")


class CompletionOTPSerializer(serializers.Serializer):
    otp = serializers.CharField(read_only=True)
    expires_at = serializers.DateTimeField(read_only=True)


class BookingStatusLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = BookingStatusLog
        fields = ["from_status", "to_status", "note", "created_at"]


class BookingSerializer(serializers.ModelSerializer):
    """Booking view for its customer, its worker and admins.

    Contact details (phone, exact address) are only included for the other
    party while the booking is active. OTP fields are never serialised.
    """

    request_id = serializers.IntegerField(source="request.id", read_only=True)
    title = serializers.CharField(source="request.title", read_only=True)
    category_name = serializers.CharField(source="request.category.display_name", read_only=True)
    preferred_time = serializers.DateTimeField(source="request.preferred_time", read_only=True)
    worker = PublicWorkerSerializer(read_only=True)
    customer_name = serializers.CharField(source="customer.full_name", read_only=True)
    contact = serializers.SerializerMethodField()
    status_history = BookingStatusLogSerializer(source="status_logs", many=True, read_only=True)
    commission = serializers.SerializerMethodField()
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    has_review = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            "id", "request_id", "title", "category_name", "preferred_time", "agreed_price", "emergency_fee",
            "total_amount", "status",
            "worker", "customer_name", "contact", "on_the_way_at", "arrived_at", "started_at", "completed_at",
            "cancelled_at", "cancel_reason", "completed_via", "status_history", "commission", "has_review",
            "created_at", "updated_at",
        ]
        read_only_fields = fields

    def _viewer(self):
        request = self.context.get("request")
        return request.user if request else None

    def get_contact(self, obj) -> dict | None:
        user = self._viewer()
        if user is None or not obj.is_active:
            return None
        if user.pk == obj.worker.user_id:
            return {
                "customer_phone": obj.customer.phone,
                "address": obj.request.address,
                "latitude": str(obj.request.latitude),
                "longitude": str(obj.request.longitude),
            }
        if user.pk == obj.customer_id:
            return {"worker_phone": obj.worker.user.phone}
        return None

    def get_commission(self, obj) -> dict | None:
        user = self._viewer()
        if user is None or user.pk == obj.customer_id:
            return None
        commission = getattr(obj, "commission", None) if hasattr(obj, "commission") else None
        if commission is None:
            return None
        return {
            "rate_percent": str(commission.rate_percent),
            "commission_amount": str(commission.commission_amount),
            "worker_earning": str(commission.worker_earning),
            "status": commission.status,
        }

    def get_has_review(self, obj) -> bool:
        return hasattr(obj, "review")
