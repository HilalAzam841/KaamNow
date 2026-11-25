from django.utils.translation import gettext as _
from django.db.models import Q
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from apps.accounts.serializers import NearbyWorkerSerializer
from apps.common.exceptions import BusinessRuleError
from apps.common.permissions import IsCustomer, IsPlatformAdmin, IsWorker

from . import services
from .models import Booking, ServiceRequest
from .serializers import (
    BookingCancelSerializer,
    BookingCompleteSerializer,
    BookingSerializer,
    BookingStatusSerializer,
    CancelSerializer,
    CompletionOTPSerializer,
    ServiceRequestCreateSerializer,
    ServiceRequestForWorkerSerializer,
    ServiceRequestSerializer,
    ServiceRequestUpdateSerializer,
)


def is_admin(request):
    return IsPlatformAdmin().has_permission(request, None)


def worker_of(user):
    if not user.is_authenticated or user.role != "worker":
        return None
    return getattr(user, "worker_profile", None)


@extend_schema_view(
    list=extend_schema(
        tags=["requests"],
        summary="Customers: your requests. Workers: open nearby requests you can bid on (scope=feed) or "
        "requests you have bid on (scope=offered). Admins: all requests.",
        parameters=[
            OpenApiParameter("status", str),
            OpenApiParameter("scope", str, enum=["feed", "offered"]),
        ],
    ),
    retrieve=extend_schema(tags=["requests"]),
    create=extend_schema(tags=["requests"], request=ServiceRequestCreateSerializer,
                         responses={201: ServiceRequestSerializer}),
    partial_update=extend_schema(tags=["requests"], request=ServiceRequestUpdateSerializer,
                                 responses={200: ServiceRequestSerializer}),
)
class ServiceRequestViewSet(
    mixins.CreateModelMixin, mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    http_method_names = ["get", "post", "patch"]
    filterset_fields = ["status", "category"]
    ordering_fields = ["created_at", "preferred_time"]

    def get_permissions(self):
        if self.action in ("create", "partial_update", "cancel", "open_to_all"):
            return [IsCustomer()]
        if self.action == "decline":
            return [IsWorker()]
        return super().get_permissions()

    def get_serializer_class(self):
        if self.action == "create":
            return ServiceRequestCreateSerializer
        if self.action == "partial_update":
            return ServiceRequestUpdateSerializer
        if getattr(self, "swagger_fake_view", False):
            return ServiceRequestSerializer
        if worker_of(self.request.user) is not None:
            return ServiceRequestForWorkerSerializer
        return ServiceRequestSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        if self.request.user.is_authenticated:
            ctx["worker"] = worker_of(self.request.user)
        return ctx

    def base_queryset(self):
        return ServiceRequest.objects.select_related("category", "customer", "invited_worker__user").prefetch_related(
            "images")

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ServiceRequest.objects.none()
        user = self.request.user
        qs = self.base_queryset()
        if is_admin(self.request):
            return qs
        if user.role == "customer":
            return qs.filter(customer=user)
        worker = worker_of(user)
        if worker is not None:
            return qs.filter(Q(offers__worker=worker) | Q(status=ServiceRequest.Status.OPEN)).distinct()
        return qs.none()

    def list(self, request, *args, **kwargs):
        worker = worker_of(request.user)
        if worker is not None and not is_admin(request):
            if request.query_params.get("scope") == "offered":
                qs = self.filter_queryset(self.base_queryset().filter(offers__worker=worker).distinct())
            else:
                qs = services.open_requests_for_worker(worker)
            page = self.paginate_queryset(qs)
            return self.get_paginated_response(self.get_serializer(page, many=True).data)
        return super().list(request, *args, **kwargs)

    def get_object(self):
        obj = get_object_or_404(self.base_queryset(), pk=self.kwargs["pk"])
        user = self.request.user
        if is_admin(self.request) or obj.customer_id == user.pk:
            return obj
        worker = worker_of(user)
        if worker is not None and (obj.offers.filter(worker=worker).exists() or services.worker_can_bid_on(worker, obj)):
            return obj
        # 404 rather than 403 so request ids cannot be probed.
        from django.http import Http404

        raise Http404

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = dict(serializer.validated_data)
        images = data.pop("images", [])
        service_request = services.create_service_request(request.user, images=images, **data)
        out = ServiceRequestSerializer(service_request, context=self.get_serializer_context()).data
        return Response(out, status=status.HTTP_201_CREATED)

    def partial_update(self, request, *args, **kwargs):
        obj = self.get_object()
        if obj.customer_id != request.user.pk:
            raise PermissionDenied(_("You can only edit your own requests."))
        if not obj.is_open:
            raise BusinessRuleError(_("Only open requests can be edited."), status_code=status.HTTP_409_CONFLICT)
        serializer = ServiceRequestUpdateSerializer(obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(ServiceRequestSerializer(obj, context=self.get_serializer_context()).data)

    @extend_schema(tags=["requests"], request=CancelSerializer, responses={200: ServiceRequestSerializer})
    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        obj = self.get_object()
        if obj.customer_id != request.user.pk:
            raise PermissionDenied(_("You can only cancel your own requests."))
        serializer = CancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        obj = services.cancel_service_request(obj, request.user, serializer.validated_data["reason"])
        return Response(ServiceRequestSerializer(obj, context=self.get_serializer_context()).data)

    @extend_schema(tags=["requests"], request=None, responses={200: ServiceRequestSerializer},
                   summary="Send a book-again job to every free matching worker nearby.")
    @action(detail=True, methods=["post"], url_path="open-to-all")
    def open_to_all(self, request, pk=None):
        obj = self.get_object()
        if obj.customer_id != request.user.pk:
            raise PermissionDenied(_("You can only change your own requests."))
        obj = services.open_to_everyone(obj)
        return Response(ServiceRequestSerializer(obj, context=self.get_serializer_context()).data)

    @extend_schema(tags=["requests"], request=None, responses={204: None},
                   summary="Invited worker: say you cannot take this job. It goes to other workers nearby.")
    @action(detail=True, methods=["post"])
    def decline(self, request, pk=None):
        obj = get_object_or_404(self.base_queryset(), pk=pk, invited_worker__user=request.user)
        services.open_to_everyone(obj, declined_by=request.user.worker_profile)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(tags=["requests"], responses={200: NearbyWorkerSerializer(many=True)})
    @action(detail=True, methods=["get"], url_path="nearby-workers")
    def nearby_workers(self, request, pk=None):
        obj = self.get_object()
        if obj.customer_id != request.user.pk and not is_admin(request):
            raise PermissionDenied(_("Only the request owner can view matching workers."))
        workers = services.find_nearby_workers(
            obj.category, obj.latitude, obj.longitude, exclude_user=obj.customer, sponsored_first=True
        )
        return Response(NearbyWorkerSerializer(workers, many=True).data)


@extend_schema_view(
    list=extend_schema(tags=["bookings"], parameters=[OpenApiParameter("status", str)]),
    retrieve=extend_schema(tags=["bookings"]),
)
class BookingViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = BookingSerializer
    filterset_fields = ["status"]
    ordering_fields = ["created_at", "agreed_price"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Booking.objects.none()
        user = self.request.user
        qs = Booking.objects.select_related(
            "request__category", "customer", "worker__user", "commission", "review"
        ).prefetch_related("status_logs", "worker__services__category", "worker__working_hours")
        if is_admin(self.request):
            return qs
        return qs.filter(Q(customer=user) | Q(worker__user=user))

    def get_throttles(self):
        if self.action in ("complete", "completion_otp"):
            self.throttle_scope = "otp"
        return super().get_throttles()

    @extend_schema(tags=["bookings"], request=BookingStatusSerializer, responses={200: BookingSerializer})
    @action(detail=True, methods=["post"])
    def status(self, request, pk=None):
        booking = self.get_object()
        serializer = BookingStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        booking = services.update_booking_status(
            booking, request.user, serializer.validated_data["status"], serializer.validated_data["note"]
        )
        return Response(BookingSerializer(self.get_queryset().get(pk=booking.pk), context={"request": request}).data)

    @extend_schema(
        tags=["bookings"], request=None, responses={201: CompletionOTPSerializer},
        summary="Customer: generate the private completion code to share with the worker",
    )
    @action(detail=True, methods=["post"], url_path="completion-otp")
    def completion_otp(self, request, pk=None):
        booking = self.get_object()
        otp, expires_at = services.issue_completion_otp(booking, request.user)
        return Response({"otp": otp, "expires_at": expires_at}, status=status.HTTP_201_CREATED)

    @extend_schema(
        tags=["bookings"], request=BookingCompleteSerializer, responses={200: BookingSerializer},
        summary="Worker: complete with the customer's OTP. Customer: confirm completion in-app.",
    )
    @action(detail=True, methods=["post"])
    def complete(self, request, pk=None):
        booking = self.get_object()
        serializer = BookingCompleteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if request.user.pk == booking.customer_id:
            if not serializer.validated_data.get("confirm"):
                raise BusinessRuleError(_("Send {\"confirm\": true} to confirm the job is complete."))
            booking = services.confirm_completion_by_customer(booking, request.user)
        elif request.user.pk == booking.worker.user_id:
            otp = serializer.validated_data.get("otp")
            if not otp:
                raise BusinessRuleError(_("Enter the completion code from the customer."))
            booking = services.complete_booking_with_otp(booking, request.user, otp)
        else:
            raise PermissionDenied()
        return Response(BookingSerializer(self.get_queryset().get(pk=booking.pk), context={"request": request}).data)

    @extend_schema(tags=["bookings"], request=BookingCancelSerializer, responses={200: BookingSerializer})
    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        booking = self.get_object()
        if request.user.pk not in (booking.customer_id, booking.worker.user_id):
            raise PermissionDenied(_("Only booking participants can cancel."))
        serializer = BookingCancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        booking = services.cancel_booking(booking, request.user, serializer.validated_data["reason"])
        return Response(BookingSerializer(self.get_queryset().get(pk=booking.pk), context={"request": request}).data)
