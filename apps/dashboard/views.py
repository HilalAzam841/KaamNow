import mimetypes
from datetime import timedelta
from decimal import Decimal

from django.db.models import Avg, Count, Q, Sum
from django.db.models.functions import TruncDate, TruncMonth
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts import services as account_services
from apps.accounts.models import User, WorkerDocument, WorkerProfile
from apps.accounts.serializers import AdminWorkerSerializer
from apps.billing.models import Commission, Payment, PlatformSettings
from apps.billing.serializers import CommissionSerializer, PlatformSettingsSerializer
from apps.common.permissions import IsPlatformAdmin
from apps.jobs.models import Booking, ServiceRequest
from apps.jobs.serializers import BookingSerializer, ServiceRequestSerializer

from .models import AuditLog
from .serializers import (
    AdminUserSerializer,
    AuditLogSerializer,
    DateRangeSerializer,
    RejectWorkerSerializer,
    SuspendUserSerializer,
)
from .services import audit

ZERO = Decimal("0.00")


def money(value):
    """Monetary values are always returned as fixed-point strings, never floats."""
    return str(Decimal(value or 0).quantize(Decimal("0.01")))
DATE_PARAMS = [OpenApiParameter("date_from", str), OpenApiParameter("date_to", str)]


class AdminAPIView(APIView):
    permission_classes = [IsPlatformAdmin]


def _date_filter(request, field="created_at"):
    rng = DateRangeSerializer(data=request.query_params)
    rng.is_valid(raise_exception=True)
    q = Q()
    if rng.validated_data.get("date_from"):
        q &= Q(**{f"{field}__date__gte": rng.validated_data["date_from"]})
    if rng.validated_data.get("date_to"):
        q &= Q(**{f"{field}__date__lte": rng.validated_data["date_to"]})
    return q


def _count_by(qs, field):
    return {row[field]: row["n"] for row in qs.values(field).annotate(n=Count("id")).order_by(field)}


class DashboardView(AdminAPIView):
    @extend_schema(tags=["admin"], responses={200: dict})
    def get(self, request):
        today = timezone.localdate()
        commissions = Commission.objects.aggregate(total=Sum("commission_amount"), gross=Sum("gross_amount"))
        return Response({
            "users": _count_by(User.objects.all(), "role"),
            "suspended_users": User.objects.filter(is_suspended=True).count(),
            "workers": {
                **_count_by(WorkerProfile.objects.all(), "verification_status"),
                "online": WorkerProfile.objects.filter(is_available=True, verification_status="verified").count(),
            },
            "requests": _count_by(ServiceRequest.objects.all(), "status"),
            "bookings": _count_by(Booking.objects.all(), "status"),
            "bookings_today": Booking.objects.filter(created_at__date=today).count(),
            "gross_booking_value": money(commissions["gross"]),
            "total_commission": money(commissions["total"]),
            "commission_rate_percent": money(PlatformSettings.load().commission_percent),
        })


@extend_schema(tags=["admin"])
class PendingWorkersView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminWorkerSerializer

    def get_queryset(self):
        return (
            WorkerProfile.objects.filter(verification_status=WorkerProfile.VerificationStatus.PENDING)
            .select_related("user").prefetch_related("documents", "services__category").order_by("created_at")
        )


@extend_schema(tags=["admin"])
class AdminWorkerDetailView(generics.RetrieveAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminWorkerSerializer
    queryset = WorkerProfile.objects.select_related("user").prefetch_related("documents", "services__category")


class VerifyWorkerView(AdminAPIView):
    @extend_schema(tags=["admin"], request=None, responses={200: AdminWorkerSerializer})
    def post(self, request, pk):
        worker = get_object_or_404(WorkerProfile, pk=pk)
        worker = account_services.verify_worker(worker, request.user, request)
        return Response(AdminWorkerSerializer(worker).data)


class RejectWorkerView(AdminAPIView):
    @extend_schema(tags=["admin"], request=RejectWorkerSerializer, responses={200: AdminWorkerSerializer})
    def post(self, request, pk):
        worker = get_object_or_404(WorkerProfile, pk=pk)
        serializer = RejectWorkerSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        worker = account_services.reject_worker(worker, request.user, serializer.validated_data["reason"], request)
        return Response(AdminWorkerSerializer(worker).data)


class WorkerDocumentFileView(AdminAPIView):
    """Streams a private CNIC/verification document to an admin. Every view is audited."""

    @extend_schema(tags=["admin"], responses={(200, "application/octet-stream"): bytes})
    def get(self, request, pk):
        document = get_object_or_404(WorkerDocument, pk=pk)
        audit(request.user, AuditLog.Action.DOCUMENT_VIEWED, document, request, worker_id=document.worker_id)
        content_type = mimetypes.guess_type(document.file.name)[0] or "application/octet-stream"
        response = FileResponse(document.file.open("rb"), content_type=content_type)
        response["Content-Disposition"] = f'inline; filename="document-{document.pk}"'
        response["Cache-Control"] = "no-store"
        return response


@extend_schema(tags=["admin"])
class AdminUsersView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminUserSerializer
    filterset_fields = ["role", "is_suspended", "is_active"]
    search_fields = ["full_name", "phone", "email"]
    queryset = User.objects.all().order_by("-date_joined")


class SuspendUserView(AdminAPIView):
    @extend_schema(tags=["admin"], request=SuspendUserSerializer, responses={200: AdminUserSerializer})
    def post(self, request, pk):
        user = get_object_or_404(User, pk=pk)
        serializer = SuspendUserSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = account_services.set_suspension(user, request.user, True, serializer.validated_data["reason"], request)
        return Response(AdminUserSerializer(user).data)


class ReactivateUserView(AdminAPIView):
    @extend_schema(tags=["admin"], request=None, responses={200: AdminUserSerializer})
    def post(self, request, pk):
        user = get_object_or_404(User, pk=pk)
        user = account_services.set_suspension(user, request.user, False, "", request)
        return Response(AdminUserSerializer(user).data)


@extend_schema(tags=["admin"], parameters=DATE_PARAMS)
class AdminRequestsView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = ServiceRequestSerializer
    filterset_fields = ["status", "category"]

    def get_queryset(self):
        return (
            ServiceRequest.objects.filter(_date_filter(self.request))
            .select_related("category", "customer").prefetch_related("images")
        )


@extend_schema(tags=["admin"], parameters=DATE_PARAMS)
class AdminBookingsView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = BookingSerializer
    filterset_fields = ["status", "worker"]
    ordering_fields = ["created_at", "agreed_price"]

    def get_queryset(self):
        return (
            Booking.objects.filter(_date_filter(self.request))
            .select_related("request__category", "customer", "worker__user", "commission", "review")
            .prefetch_related("status_logs", "worker__services__category")
        )


class RevenueView(AdminAPIView):
    @extend_schema(tags=["admin"], parameters=DATE_PARAMS, responses={200: dict})
    def get(self, request):
        qs = Commission.objects.filter(_date_filter(request))
        totals = qs.aggregate(
            bookings=Count("id"), gross=Sum("gross_amount"), commission=Sum("commission_amount"),
            worker_earnings=Sum("worker_earning"),
            collected=Sum("commission_amount", filter=Q(status=Commission.Status.COLLECTED)),
            pending=Sum("commission_amount", filter=Q(status=Commission.Status.PENDING)),
        )
        monthly = (
            qs.annotate(month=TruncMonth("created_at")).values("month")
            .annotate(bookings=Count("id"), gross=Sum("gross_amount"), commission=Sum("commission_amount"))
            .order_by("month")
        )
        payments = Payment.objects.filter(_date_filter(request), status=Payment.Status.COMPLETED)
        return Response({
            "completed_bookings": totals["bookings"],
            "gross_booking_value": money(totals["gross"]),
            "commission_revenue": money(totals["commission"]),
            "worker_earnings": money(totals["worker_earnings"]),
            "commission_collected": money(totals["collected"]),
            "commission_pending": money(totals["pending"]),
            "payments_received": money(payments.aggregate(s=Sum("amount"))["s"]),
            "payments_by_method": {
                r["method"]: money(r["s"]) for r in payments.values("method").annotate(s=Sum("amount")).order_by("method")
            },
            "monthly": [
                {"month": r["month"].date().isoformat(), "bookings": r["bookings"], "gross": money(r["gross"]),
                 "commission": money(r["commission"])}
                for r in monthly
            ],
        })


@extend_schema(tags=["admin"], parameters=DATE_PARAMS)
class CommissionsView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = CommissionSerializer
    filterset_fields = ["status", "worker"]

    def get_queryset(self):
        return Commission.objects.filter(_date_filter(self.request)).select_related("worker__user")


class CommissionSettingsView(AdminAPIView):
    @extend_schema(tags=["admin"], responses={200: PlatformSettingsSerializer})
    def get(self, request):
        return Response(PlatformSettingsSerializer(PlatformSettings.load()).data)

    @extend_schema(tags=["admin"], request=PlatformSettingsSerializer, responses={200: PlatformSettingsSerializer})
    def patch(self, request):
        settings_obj = PlatformSettings.load()
        old = settings_obj.commission_percent
        serializer = PlatformSettingsSerializer(settings_obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(updated_by=request.user)
        audit(request.user, AuditLog.Action.COMMISSION_CHANGED, settings_obj, request,
              old=str(old), new=str(settings_obj.commission_percent))
        return Response(PlatformSettingsSerializer(settings_obj).data)


class ReportsView(AdminAPIView):
    @extend_schema(tags=["admin"], parameters=DATE_PARAMS, responses={200: dict})
    def get(self, request):
        date_q = _date_filter(request)
        bookings = Booking.objects.filter(date_q)
        requests_qs = ServiceRequest.objects.filter(date_q)
        since = timezone.now() - timedelta(days=30)
        by_category = (
            bookings.values("request__category__name")
            .annotate(bookings=Count("id"), completed=Count("id", filter=Q(status=Booking.Status.COMPLETED)),
                      avg_price=Avg("agreed_price"))
            .order_by("-bookings")
        )
        top_workers = (
            WorkerProfile.objects.filter(verification_status="verified")
            .order_by("-completed_jobs_count", "-average_rating")
            .select_related("user")[:10]
        )
        daily = (
            Booking.objects.filter(created_at__gte=since).annotate(day=TruncDate("created_at"))
            .values("day").annotate(n=Count("id")).order_by("day")
        )
        total_requests = requests_qs.count()
        booked = requests_qs.filter(status=ServiceRequest.Status.BOOKED).count()
        return Response({
            "requests_by_status": _count_by(requests_qs, "status"),
            "bookings_by_status": _count_by(bookings, "status"),
            "request_to_booking_conversion": round(booked / total_requests, 4) if total_requests else 0,
            "bookings_by_category": [
                {"category": r["request__category__name"], "bookings": r["bookings"], "completed": r["completed"],
                 "avg_price": money(r["avg_price"]) if r["avg_price"] is not None else None}
                for r in by_category
            ],
            "top_workers": [
                {"id": w.pk, "name": w.user.full_name, "completed_jobs": w.completed_jobs_count,
                 "average_rating": str(w.average_rating)}
                for w in top_workers
            ],
            "daily_bookings_last_30_days": [{"date": r["day"].isoformat(), "bookings": r["n"]} for r in daily],
        })


@extend_schema(tags=["admin"])
class AuditLogView(generics.ListAPIView):
    permission_classes = [IsPlatformAdmin]
    serializer_class = AuditLogSerializer
    filterset_fields = ["action", "actor", "target_type"]
    queryset = AuditLog.objects.select_related("actor")
