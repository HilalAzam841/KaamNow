from django.utils.translation import gettext as _
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings
from django.utils import timezone
from rest_framework import serializers

from apps.accounts.models import WorkerProfile
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
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90, required=False)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180,
                                         required=False)
    saved_address = serializers.IntegerField(
        required=False, write_only=True,
        help_text="One of your saved addresses. Fills latitude, longitude, address and area (they can be left out).")
    worker = serializers.PrimaryKeyRelatedField(
        source="invited_worker", required=False, allow_null=True, write_only=True,
        queryset=WorkerProfile.objects.select_related("user").filter(
            verification_status=WorkerProfile.VerificationStatus.VERIFIED),
        help_text="Book one worker again: only this worker sees the job, at a time they are free. "
                  "Leave out to send the job to every matching worker nearby.",
    )

    class Meta:
        model = ServiceRequest
        fields = [
            "id", "category", "title", "description", "latitude", "longitude", "address", "area",
            "preferred_time", "duration_minutes", "budget", "is_emergency", "images", "worker", "saved_address",
        ]
        read_only_fields = ["id"]
        extra_kwargs = {
            "address": {"required": False},
            "budget": {"min_value": Decimal("0")},
            "duration_minutes": {"min_value": 30, "max_value": 480, "required": False},
        }

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

    def validate(self, attrs):
        saved_id = attrs.pop("saved_address", None)
        if saved_id is not None:
            from apps.addresses.models import SavedAddress

            request = self.context.get("request")
            saved = SavedAddress.objects.filter(pk=saved_id, user=getattr(request, "user", None)).first()
            if saved is None:
                raise serializers.ValidationError({"saved_address": _("This saved address was not found.")})
            attrs.update(latitude=saved.latitude, longitude=saved.longitude, address=saved.address)
            attrs.setdefault("area", saved.area)
            if not attrs["area"]:
                attrs["area"] = saved.area
        missing = {k: _("This field is required.") for k in ("latitude", "longitude", "address") if not attrs.get(k)}
        if missing:
            raise serializers.ValidationError(missing)
        return attrs


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
    invited_worker = serializers.SerializerMethodField()

    class Meta:
        model = ServiceRequest
        fields = [
            "id", "category", "category_name", "title", "description", "latitude", "longitude", "address", "area",
            "preferred_time", "duration_minutes", "budget", "is_emergency", "emergency_fee", "status", "images",
            "offers_count",
            "booking_id", "matched_workers_count", "invited_worker", "package",
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

    def get_invited_worker(self, obj) -> dict | None:
        """The one worker this job was sent to (book again), or null when it is open to everyone."""
        w = obj.invited_worker
        return None if w is None else {"id": w.pk, "full_name": w.user.full_name}


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
    is_direct = serializers.SerializerMethodField()

    class Meta:
        model = ServiceRequest
        fields = [
            "id", "is_direct", "category", "category_name", "title", "description", "area", "approx_latitude",
            "approx_longitude", "distance_km", "preferred_time", "duration_minutes", "budget", "is_emergency",
            "emergency_fee", "status",
            "images", "customer_name",
            "my_offer_id", "created_at",
        ]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        return obj.customer.full_name.split(" ")[0]

    def get_is_direct(self, obj) -> bool:
        """True when the customer asked for this worker by name (book again)."""
        worker = self.context.get("worker")
        return worker is not None and obj.invited_worker_id == worker.pk

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


class NoShowSerializer(serializers.Serializer):
    note = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")


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
    duration_minutes = serializers.IntegerField(source="request.duration_minutes", read_only=True)
    package_id = serializers.IntegerField(
        source="request.package_id", read_only=True, allow_null=True,
        help_text="The fixed-price package this booking came from, or null for a bid job.")
    worker = PublicWorkerSerializer(read_only=True)
    customer_name = serializers.CharField(source="customer.full_name", read_only=True)
    contact = serializers.SerializerMethodField()
    status_history = BookingStatusLogSerializer(source="status_logs", many=True, read_only=True)
    commission = serializers.SerializerMethodField()
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    has_review = serializers.SerializerMethodField()
    no_show = serializers.SerializerMethodField()
    safety = serializers.SerializerMethodField()
    cancellation_fee = serializers.SerializerMethodField()
    tip = serializers.SerializerMethodField()
    can_tip = serializers.SerializerMethodField()
    job_photos = serializers.SerializerMethodField()
    guarantee = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            "id", "request_id", "title", "category_name", "preferred_time", "duration_minutes", "agreed_price",
            "emergency_fee", "package_id",
            "total_amount", "status",
            "worker", "customer_name", "contact", "on_the_way_at", "arrived_at", "started_at", "completed_at",
            "cancelled_at", "cancel_reason", "completed_via", "status_history", "commission", "has_review",
            "no_show", "safety", "cancellation_fee", "tip", "can_tip", "job_photos", "guarantee",
            "created_at", "updated_at",
        ]
        read_only_fields = fields

    def get_job_photos(self, obj) -> dict:
        """Before and after photo counts, the limit per kind, and whether the viewer (the worker) can add more."""
        from apps.jobphotos.services import summary

        return summary(obj, self._viewer())

    def get_guarantee(self, obj) -> dict:
        """The work guarantee: until when it lasts, whether the viewer can claim now, and the claim if any."""
        from apps.guarantee import services as guarantee
        from apps.guarantee.serializers import GuaranteeClaimSerializer

        claim = getattr(obj, "guarantee_claim", None) if hasattr(obj, "guarantee_claim") else None
        until = guarantee.window_ends(obj)
        return {
            "until": until.isoformat() if until else None,
            "can_claim": guarantee.can_claim(obj, self._viewer()),
            "claim": GuaranteeClaimSerializer(claim).data if claim else None,
        }

    def _viewer(self):
        request = self.context.get("request")
        return request.user if request else None

    def get_cancellation_fee(self, obj) -> dict | None:
        """The late cancellation fee charged on this booking (id, amount, worker_share, status, reason), or null."""
        fee = getattr(obj, "cancellation_fee", None) if hasattr(obj, "cancellation_fee") else None
        if fee is None:
            return None
        return {"id": fee.pk, "amount": f"{fee.amount:.2f}", "worker_share": f"{fee.worker_share:.2f}",
                "status": fee.status, "reason": fee.reason}

    def get_tip(self, obj) -> dict | None:
        """The tip on this booking (id, amount, method, status, message), or null. A cancelled tip shows as null."""
        tip = getattr(obj, "tip", None) if hasattr(obj, "tip") else None
        if tip is None or tip.status == "cancelled":
            return None
        return {"id": tip.pk, "amount": f"{tip.amount:.2f}", "method": tip.method, "status": tip.status,
                "message": tip.message}

    def get_can_tip(self, obj) -> bool:
        """Whether the viewer can give (or change an unpaid) tip now."""
        from apps.tips.services import can_tip

        user = self._viewer()
        if user is None or not user.is_authenticated:
            return False
        tip = getattr(obj, "tip", None) if hasattr(obj, "tip") else None
        if tip is not None and tip.status == "paid":
            return False
        return can_tip(obj, user)

    def get_no_show(self, obj) -> dict:
        """reported: who was reported absent (worker or customer), or null.
        you_can_report: who the viewer may report absent, and opens_at: from when."""
        from apps.reminders.services import grace_period, no_show_side_for

        report = getattr(obj, "no_show", None) if hasattr(obj, "no_show") else None
        out = {"reported": report.side if report else None, "you_can_report": None, "opens_at": None}
        user = self._viewer()
        if report is None and user is not None and user.is_authenticated:
            if not hasattr(self, "_grace"):
                self._grace = grace_period()
            side, opens_at = no_show_side_for(obj, user, self._grace)
            if side:
                out["you_can_report"], out["opens_at"] = side, opens_at.isoformat()
        return out

    def get_safety(self, obj) -> dict:
        """For the viewer: can_sos (SOS button shown), sos_status (their open alert, or null),
        sharing_until (when their trip-sharing link ends, or null)."""
        from apps.safety import services as safety

        user = self._viewer()
        out = {"can_sos": False, "sos_status": None, "sharing_until": None}
        if user is None or not user.is_authenticated or user.pk not in (obj.customer_id, obj.worker.user_id):
            return out
        out["can_sos"] = safety.can_raise_sos(obj)
        alert = safety.open_alert(obj, user)
        out["sos_status"] = alert.status if alert else None
        share = safety.active_share(obj, user)
        out["sharing_until"] = share.expires_at.isoformat() if share else None
        return out

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
