import logging

from django.utils.translation import gettext as _
from django.conf import settings
from django.contrib.auth import password_validation
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils.encoding import force_bytes, force_str
from django.utils import timezone
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, permissions, serializers, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from apps.catalog.models import ServiceCategory
from apps.common import sms
from apps.common.exceptions import BusinessRuleError
from apps.common.permissions import IsWorker
from apps.common.validators import normalize_pk_phone
from apps.jobs.services import find_nearby_workers

from . import phone as phone_codes
from . import services
from .models import PhoneCode, User, WorkerDocument, WorkerProfile
from .serializers import (
    AvailabilitySerializer,
    LoginSerializer,
    LogoutSerializer,
    NearbyQuerySerializer,
    NearbyWorkerSerializer,
    PasswordChangeSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    PasswordResetSmsConfirmSerializer,
    PhoneCodeSerializer,
    PublicWorkerSerializer,
    RegisterSerializer,
    UserSerializer,
    WorkerDocumentSerializer,
    WorkerProfileSerializer,
    tokens_for,
)

logger = logging.getLogger(__name__)


class AuthResponseSerializer(serializers.Serializer):
    user = UserSerializer()
    tokens = serializers.DictField(child=serializers.CharField())


# --------------------------------------------------------------------------
# Authentication
# --------------------------------------------------------------------------
class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "auth"

    @extend_schema(request=RegisterSerializer, responses={201: AuthResponseSerializer}, tags=["auth"])
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = services.register_user(**serializer.validated_data)
        return Response({"user": UserSerializer(user).data, "tokens": tokens_for(user)}, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "auth"

    @extend_schema(request=LoginSerializer, responses={200: AuthResponseSerializer}, tags=["auth"])
    def post(self, request):
        serializer = LoginSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]
        from django.contrib.auth.models import update_last_login

        update_last_login(None, user)
        return Response({"user": UserSerializer(user).data, "tokens": tokens_for(user)})


@extend_schema(tags=["auth"])
class RefreshView(TokenRefreshView):
    throttle_scope = "auth"


class LogoutView(APIView):
    @extend_schema(request=LogoutSerializer, responses={200: None}, tags=["auth"])
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            token = RefreshToken(serializer.validated_data["refresh"])
            if token.get("user_id") is not None and str(token["user_id"]) != str(request.user.pk):
                return Response({"detail": "Token does not belong to this user."}, status=status.HTTP_400_BAD_REQUEST)
            token.blacklist()
        except TokenError:
            return Response({"detail": "Invalid or expired refresh token."}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"detail": "Logged out."})


@extend_schema(tags=["auth"])
class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    http_method_names = ["get", "patch"]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_object(self):
        return self.request.user


class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "password_reset"

    @extend_schema(request=PasswordResetRequestSerializer, responses={200: None}, tags=["auth"])
    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        query = Q()
        if data.get("email"):
            query |= Q(email__iexact=data["email"])
        if data.get("phone"):
            try:
                query |= Q(phone=normalize_pk_phone(data["phone"]))
            except DjangoValidationError:
                pass
        user = User.objects.filter(query, is_active=True).first() if query else None
        sms_code = bool(data.get("phone")) and sms.is_available()
        if user and sms_code and data.get("phone") and user.phone == _normalized(data["phone"]):
            try:
                phone_codes.issue_code(user.phone, PhoneCode.Purpose.RESET, language=user.language)
            except BusinessRuleError as exc:
                # Same answer either way, so nobody can tell from it whether the number has an account.
                logger.info("Reset code not sent: %s", exc.detail)
        if user and user.email:
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            link = settings.PASSWORD_RESET_URL.format(uid=uid, token=token)
            send_mail(
                "Reset your KaamNow password",
                f"Use this link to reset your password: {link}\nIf you did not request this, ignore this email.",
                None, [user.email],
            )
        # Same response whether or not the account exists (prevents account enumeration).
        return Response({
            "detail": _("If an account matches, password reset instructions have been sent."),
            "sms_code": sms_code,
        })


class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "password_reset"

    @extend_schema(request=PasswordResetConfirmSerializer, responses={200: None}, tags=["auth"])
    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            user = User.objects.get(pk=force_str(urlsafe_base64_decode(data["uid"])))
        except (User.DoesNotExist, ValueError, TypeError, OverflowError):
            user = None
        if user is None or not default_token_generator.check_token(user, data["token"]):
            return Response({"detail": "Invalid or expired reset link."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            password_validation.validate_password(data["new_password"], user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"new_password": exc.messages})
        user.set_password(data["new_password"])
        user.save(update_fields=["password", "updated_at"])
        return Response({"detail": "Password has been reset. Please log in."})


class PasswordResetSmsConfirmView(APIView):
    """Resets a forgotten password with the code sent by SMS. Signs the account out everywhere."""

    permission_classes = [permissions.AllowAny]
    throttle_scope = "password_reset"

    @extend_schema(request=PasswordResetSmsConfirmSerializer, responses={200: None}, tags=["auth"])
    def post(self, request):
        serializer = PasswordResetSmsConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        phone = _normalized(data["phone"])
        user = User.objects.filter(phone=phone, is_active=True).first() if phone else None
        if user is None or not phone_codes.check_code(phone, PhoneCode.Purpose.RESET, data["code"]):
            return Response({"detail": _("Wrong or expired code.")}, status=status.HTTP_400_BAD_REQUEST)
        try:
            password_validation.validate_password(data["new_password"], user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"new_password": exc.messages})
        user.set_password(data["new_password"])
        fields = ["password", "updated_at"]
        if not user.phone_verified:  # receiving the code proves the number is theirs
            user.phone_verified_at = timezone.now()
            fields.append("phone_verified_at")
        user.save(update_fields=fields)
        _sign_out_everywhere(user)
        return Response({"detail": _("Password has been reset. Please log in.")})


class PhoneSendCodeView(APIView):
    """Sends a code by SMS to the signed-in user's own phone number."""

    throttle_scope = "phone_code"

    @extend_schema(request=None, responses={200: None}, tags=["auth"])
    def post(self, request):
        user = request.user
        if user.phone_verified:
            raise BusinessRuleError(_("Your phone number is already confirmed."))
        if not sms.is_available():
            raise BusinessRuleError(_("SMS is not set up on this server."), status_code=503)
        phone_codes.issue_code(user.phone, PhoneCode.Purpose.VERIFY, language=user.language)
        return Response({
            "detail": _("Code sent."),
            "resend_after": settings.KAAMNOW["PHONE_CODE_RESEND_SECONDS"],
            "expires_in_minutes": settings.KAAMNOW["PHONE_CODE_TTL_MINUTES"],
        })


class PhoneVerifyView(APIView):
    throttle_scope = "otp"

    @extend_schema(request=PhoneCodeSerializer, responses={200: UserSerializer}, tags=["auth"])
    def post(self, request):
        serializer = PhoneCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.phone_verified:
            if not phone_codes.check_code(user.phone, PhoneCode.Purpose.VERIFY, serializer.validated_data["code"]):
                raise BusinessRuleError(_("Wrong or expired code."), code="invalid_code")
            user.phone_verified_at = timezone.now()
            user.save(update_fields=["phone_verified_at", "updated_at"])
        return Response(UserSerializer(user, context={"request": request}).data)


def _normalized(phone):
    try:
        return normalize_pk_phone(phone)
    except DjangoValidationError:
        return None


def _sign_out_everywhere(user):
    from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

    for token in OutstandingToken.objects.filter(user=user).exclude(blacklistedtoken__isnull=False):
        BlacklistedToken.objects.get_or_create(token=token)


class PasswordChangeView(APIView):
    @extend_schema(request=PasswordChangeSerializer, responses={200: None}, tags=["auth"])
    def post(self, request):
        serializer = PasswordChangeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.check_password(serializer.validated_data["current_password"]):
            raise serializers.ValidationError({"current_password": _("Current password is incorrect.")})
        try:
            password_validation.validate_password(serializer.validated_data["new_password"], user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"new_password": exc.messages})
        user.set_password(serializer.validated_data["new_password"])
        user.save(update_fields=["password", "updated_at"])
        return Response({"detail": "Password changed."})


# --------------------------------------------------------------------------
# Workers
# --------------------------------------------------------------------------
@extend_schema(tags=["workers"])
class WorkerMeView(generics.RetrieveUpdateAPIView):
    serializer_class = WorkerProfileSerializer
    permission_classes = [IsWorker]
    http_method_names = ["get", "patch"]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_object(self):
        return (
            WorkerProfile.objects.select_related("user")
            .prefetch_related("services__category")
            .get(user=self.request.user)
        )


@extend_schema(tags=["workers"])
class WorkerDocumentView(generics.ListCreateAPIView):
    serializer_class = WorkerDocumentSerializer
    permission_classes = [IsWorker]
    parser_classes = [MultiPartParser, FormParser]
    pagination_class = None

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return WorkerDocument.objects.none()
        return WorkerDocument.objects.filter(worker__user=self.request.user)

    def perform_create(self, serializer):
        worker = self.request.user.worker_profile
        upload = serializer.validated_data["file"]
        serializer.save(worker=worker, original_filename=upload.name[:255])
        if worker.verification_status == WorkerProfile.VerificationStatus.REJECTED:
            worker.verification_status = WorkerProfile.VerificationStatus.PENDING
            worker.save(update_fields=["verification_status", "updated_at"])


class WorkerAvailabilityView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(request=AvailabilitySerializer, responses={200: WorkerProfileSerializer}, tags=["workers"])
    def post(self, request):
        serializer = AvailabilitySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        worker = services.set_availability(request.user.worker_profile, serializer.validated_data["is_available"])
        return Response(WorkerProfileSerializer(worker).data)


class NearbyWorkersView(APIView):
    """Verified, online workers in a category whose service radius covers the point."""

    @extend_schema(
        parameters=[
            OpenApiParameter("category", int, required=True),
            OpenApiParameter("latitude", float, required=True),
            OpenApiParameter("longitude", float, required=True),
        ],
        responses={200: NearbyWorkerSerializer(many=True)},
        tags=["workers"],
    )
    def get(self, request):
        query = NearbyQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        category = get_object_or_404(ServiceCategory, pk=query.validated_data["category"], is_active=True)
        workers = find_nearby_workers(
            category, query.validated_data["latitude"], query.validated_data["longitude"], exclude_user=request.user,
            sponsored_first=True,
        )
        return Response(NearbyWorkerSerializer(workers, many=True).data)


@extend_schema(tags=["workers"])
class PublicWorkerDetailView(generics.RetrieveAPIView):
    serializer_class = PublicWorkerSerializer
    permission_classes = [permissions.AllowAny]
    queryset = WorkerProfile.objects.select_related("user").prefetch_related("services__category").filter(
        verification_status=WorkerProfile.VerificationStatus.VERIFIED, user__is_active=True, user__is_suspended=False
    )
