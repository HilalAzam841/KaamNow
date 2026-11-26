from django.db.models import Q
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.billing.serializers import PaymentWithCheckoutSerializer
from apps.common.permissions import IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from . import services
from .models import CancellationFee
from .serializers import (
    AdminCancellationFeeSerializer,
    CancellationFeeSerializer,
    PayFeeSerializer,
    RecordReceivedSerializer,
    WaiveSerializer,
)


@extend_schema(tags=["cancellations"])
class CancellationFeeViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Late cancellation fees: the customer's own, or the ones owed to a worker."""

    permission_classes = [IsAuthenticated]
    serializer_class = CancellationFeeSerializer
    filterset_fields = ["status"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return CancellationFee.objects.none()
        user = self.request.user
        return CancellationFee.objects.select_related("booking__request", "payment").filter(
            Q(customer=user) | Q(worker__user=user))

    @extend_schema(request=PayFeeSerializer, responses={201: PaymentWithCheckoutSerializer},
                   summary="Customer pays a fee online. Open `checkout`; the server confirms after the gateway "
                           "callback is verified.")
    @action(detail=True, methods=["post"])
    def pay(self, request, pk=None):
        fee = self.get_object()
        if fee.customer_id != request.user.pk:
            raise PermissionDenied()
        s = PayFeeSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        payment, checkout = services.pay(fee, request.user, s.validated_data["method"])
        payment.checkout = checkout
        return Response(PaymentWithCheckoutSerializer(payment).data, status=201)


@extend_schema(tags=["admin"])
class AdminCancellationFeeViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Every late cancellation fee, newest first."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminCancellationFeeSerializer
    filterset_fields = ["status", "customer", "worker", "reason"]

    def get_queryset(self):
        return CancellationFee.objects.select_related("booking__request", "payment", "customer", "worker__user")

    @extend_schema(request=WaiveSerializer, responses={200: AdminCancellationFeeSerializer},
                   summary="Waive a fee (audited). The customer is told.")
    @action(detail=True, methods=["post"])
    def waive(self, request, pk=None):
        s = WaiveSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        fee = services.waive(self.get_object(), request.user, s.validated_data["reason"])
        audit(request.user, AuditLog.Action.CANCELLATION_FEE_SETTLED, fee, request, outcome="waived",
              reason=fee.waived_reason, amount=str(fee.amount), booking=fee.booking_id)
        return Response(AdminCancellationFeeSerializer(fee).data)

    @extend_schema(request=RecordReceivedSerializer, responses={200: AdminCancellationFeeSerializer},
                   summary="Record a fee paid at the office or by transfer (audited). The worker's share goes "
                           "to their wallet.")
    @action(detail=True, methods=["post"], url_path="record-received")
    def record_received(self, request, pk=None):
        s = RecordReceivedSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        fee = services.record_received(self.get_object(), request.user, s.validated_data["reference"])
        audit(request.user, AuditLog.Action.CANCELLATION_FEE_SETTLED, fee, request, outcome="received",
              reference=s.validated_data["reference"], amount=str(fee.amount), booking=fee.booking_id)
        return Response(AdminCancellationFeeSerializer(fee).data)
