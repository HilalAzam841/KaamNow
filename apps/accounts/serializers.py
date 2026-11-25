from django.utils.translation import gettext as _
from django.contrib.auth import authenticate, password_validation
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.models import WorkerService
from apps.common.validators import normalize_cnic, normalize_pk_phone, validate_document_upload

from .models import User, WorkerDocument, WorkerProfile


def tokens_for(user):
    refresh = RefreshToken.for_user(user)
    refresh["role"] = user.role
    return {"refresh": str(refresh), "access": str(refresh.access_token)}


class UserSerializer(serializers.ModelSerializer):
    """The authenticated user's own account (includes private fields)."""

    worker_profile_id = serializers.SerializerMethodField()
    phone_verified = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = [
            "id", "phone", "phone_verified", "email", "full_name", "role", "avatar", "default_address", "language",
            "booking_reminders", "worker_profile_id", "date_joined",
        ]
        read_only_fields = ["id", "phone", "phone_verified", "role", "date_joined", "worker_profile_id"]

    def get_worker_profile_id(self, obj) -> int | None:
        profile = getattr(obj, "worker_profile", None)
        return profile.pk if profile else None

    def validate_email(self, value):
        if not value:
            return None
        value = value.lower()
        if User.objects.filter(email__iexact=value).exclude(pk=self.instance.pk if self.instance else None).exists():
            raise serializers.ValidationError(_("This email is already in use."))
        return value


class RegisterSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True, min_length=8, style={"input_type": "password"})
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    role = serializers.ChoiceField(choices=[User.Role.CUSTOMER, User.Role.WORKER], default=User.Role.CUSTOMER)
    cnic_number = serializers.CharField(required=False, allow_blank=True, max_length=15)
    referral_code = serializers.CharField(required=False, allow_blank=True, max_length=12,
                                          help_text="Invite code from a friend (new customers get welcome credit).")

    def validate_referral_code(self, value):
        from apps.promotions.models import ReferralCode

        value = (value or "").strip().upper()
        if value and not ReferralCode.objects.filter(code=value).exists():
            raise serializers.ValidationError(_("This invite code does not exist."))
        return value

    def validate_phone(self, value):
        try:
            phone = normalize_pk_phone(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages)
        if User.objects.filter(phone=phone).exists():
            raise serializers.ValidationError(_("An account with this phone number already exists."))
        return phone

    def validate_email(self, value):
        if not value:
            return None
        value = value.lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError(_("An account with this email already exists."))
        return value

    def validate_full_name(self, value):
        value = value.strip()
        if len(value) < 2:
            raise serializers.ValidationError(_("Enter your full name."))
        return value

    def validate(self, attrs):
        if attrs["role"] == User.Role.WORKER:
            cnic = attrs.get("cnic_number")
            if not cnic:
                raise serializers.ValidationError({"cnic_number": _("CNIC number is required for service providers.")})
            try:
                attrs["cnic_number"] = normalize_cnic(cnic)
            except DjangoValidationError as exc:
                raise serializers.ValidationError({"cnic_number": exc.messages})
            if WorkerProfile.objects.filter(cnic_number=attrs["cnic_number"]).exists():
                raise serializers.ValidationError({"cnic_number": _("This CNIC is already registered.")})
        else:
            attrs.pop("cnic_number", None)
        candidate = User(phone=attrs["phone"], full_name=attrs["full_name"], email=attrs.get("email"))
        try:
            password_validation.validate_password(attrs["password"], candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": exc.messages})
        return attrs


class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField()
    password = serializers.CharField(write_only=True, style={"input_type": "password"})

    def validate(self, attrs):
        try:
            phone = normalize_pk_phone(attrs["phone"])
        except DjangoValidationError:
            raise serializers.ValidationError(_("Invalid phone number or password."), code="invalid_credentials")
        user = authenticate(request=self.context.get("request"), phone=phone, password=attrs["password"])
        if user is None:
            raise serializers.ValidationError(_("Invalid phone number or password."), code="invalid_credentials")
        if user.is_suspended:
            raise serializers.ValidationError(_("This account is suspended. Contact support."), code="account_suspended")
        attrs["user"] = user
        return attrs


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class PasswordResetRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)

    def validate(self, attrs):
        if not attrs.get("phone") and not attrs.get("email"):
            raise serializers.ValidationError(_("Provide your phone number or email."))
        return attrs


class PasswordResetConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True, min_length=8)


class PhoneCodeSerializer(serializers.Serializer):
    code = serializers.RegexField(r"^\s*\d{4,8}\s*$", max_length=12)


class PasswordResetSmsConfirmSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    code = serializers.RegexField(r"^\s*\d{4,8}\s*$", max_length=12)
    new_password = serializers.CharField(write_only=True, min_length=8)


class PasswordChangeSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)


class WorkerServiceInlineSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.display_name", read_only=True)

    class Meta:
        model = WorkerService
        fields = ["id", "category", "category_name", "description", "starting_price", "is_active"]


class WorkerProfileSerializer(serializers.ModelSerializer):
    """The worker's own profile (private view)."""

    full_name = serializers.CharField(source="user.full_name", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)
    services = WorkerServiceInlineSerializer(many=True, read_only=True)
    documents_uploaded = serializers.SerializerMethodField()

    class Meta:
        model = WorkerProfile
        fields = [
            "id", "full_name", "phone", "cnic_number", "bio", "experience_years", "profile_picture",
            "base_latitude", "base_longitude", "service_area", "service_radius_km", "is_available",
            "verification_status", "rejection_reason", "verified_at", "average_rating", "rating_count",
            "completed_jobs_count", "services", "documents_uploaded", "created_at",
        ]
        read_only_fields = [
            "id", "is_available", "verification_status", "rejection_reason", "verified_at", "average_rating",
            "rating_count", "completed_jobs_count", "created_at",
        ]

    def get_documents_uploaded(self, obj) -> list[str]:
        return sorted(set(obj.documents.values_list("document_type", flat=True)))

    def validate_cnic_number(self, value):
        try:
            value = normalize_cnic(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages)
        if self.instance and self.instance.is_verified and value != self.instance.cnic_number:
            raise serializers.ValidationError(_("CNIC cannot be changed after verification. Contact support."))
        if WorkerProfile.objects.filter(cnic_number=value).exclude(pk=self.instance.pk).exists():
            raise serializers.ValidationError(_("This CNIC is already registered."))
        return value

    def validate(self, attrs):
        lat = attrs.get("base_latitude", getattr(self.instance, "base_latitude", None))
        lng = attrs.get("base_longitude", getattr(self.instance, "base_longitude", None))
        if (lat is None) != (lng is None):
            raise serializers.ValidationError(_("Provide both base_latitude and base_longitude."))
        return attrs

    def update(self, instance, validated_data):
        cnic_changed = "cnic_number" in validated_data and validated_data["cnic_number"] != instance.cnic_number
        instance = super().update(instance, validated_data)
        if cnic_changed and instance.verification_status == WorkerProfile.VerificationStatus.REJECTED:
            instance.verification_status = WorkerProfile.VerificationStatus.PENDING
            instance.save(update_fields=["verification_status", "updated_at"])
        return instance


class PublicWorkerSerializer(serializers.ModelSerializer):
    """Public worker card: no phone, CNIC, documents or exact home location."""

    full_name = serializers.CharField(source="user.full_name", read_only=True)
    is_verified = serializers.BooleanField(read_only=True)
    services = WorkerServiceInlineSerializer(many=True, read_only=True)
    plan_badge = serializers.SerializerMethodField()
    working_hours = serializers.SerializerMethodField()

    class Meta:
        model = WorkerProfile
        fields = [
            "id", "full_name", "profile_picture", "bio", "experience_years", "service_area", "is_verified",
            "average_rating", "rating_count", "completed_jobs_count", "plan_badge", "services", "working_hours",
        ]
        read_only_fields = fields

    def get_working_hours(self, obj) -> list[dict]:
        """Weekly hours (empty when the worker has not set any: available any time)."""
        return [{"weekday": h.weekday, "start": h.start_time.strftime("%H:%M"), "end": h.end_time.strftime("%H:%M")}
                for h in obj.working_hours.all()]

    def get_plan_badge(self, obj) -> str:
        from apps.billing.services import current_plan

        plan = current_plan(obj)
        return plan.badge if plan else ""


class PublicWorkerDetailSerializer(PublicWorkerSerializer):
    is_favourite = serializers.SerializerMethodField()

    class Meta(PublicWorkerSerializer.Meta):
        fields = PublicWorkerSerializer.Meta.fields + ["is_favourite"]

    def get_is_favourite(self, obj) -> bool:
        """Whether the signed-in customer saved this worker."""
        return obj.pk in self.context.get("favourite_ids", set())


class NearbyWorkerSerializer(PublicWorkerSerializer):
    distance_km = serializers.FloatField(read_only=True)
    is_available = serializers.BooleanField(read_only=True)
    is_sponsored = serializers.BooleanField(
        read_only=True, default=False, help_text="Paid featured placement. The app must label it 'Sponsored'."
    )

    class Meta(PublicWorkerSerializer.Meta):
        fields = PublicWorkerSerializer.Meta.fields + ["distance_km", "is_available", "is_sponsored"]
        read_only_fields = fields


class AvailabilitySerializer(serializers.Serializer):
    is_available = serializers.BooleanField()


class WorkerDocumentSerializer(serializers.ModelSerializer):
    """Metadata only. The file itself is private and never returned as a URL."""

    file = serializers.FileField(write_only=True, validators=[validate_document_upload])

    class Meta:
        model = WorkerDocument
        fields = ["id", "document_type", "file", "original_filename", "status", "created_at"]
        read_only_fields = ["id", "original_filename", "status", "created_at"]


class AdminWorkerSerializer(WorkerProfileSerializer):
    email = serializers.CharField(source="user.email", read_only=True)
    documents = WorkerDocumentSerializer(many=True, read_only=True)
    user_id = serializers.IntegerField(source="user.id", read_only=True)

    class Meta(WorkerProfileSerializer.Meta):
        fields = WorkerProfileSerializer.Meta.fields + ["email", "documents", "user_id"]
        read_only_fields = fields


class NearbyQuerySerializer(serializers.Serializer):
    category = serializers.IntegerField()
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180)
