from decimal import Decimal

from django.db.models import Count, Q, Sum
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsCustomer, IsPlatformAdmin, IsWorker

from . import services
from .models import Commission, Payment
from .serializers import (
    EarningsSummarySerializer,
    PaymentCreateSerializer,
    PaymentSerializer,
)


@extend_schema_view(list=extend_schema(tags=["payments"]), retrieve=extend_schema(tags=["payments"]))
class PaymentViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = PaymentSerializer
    filterset_fields = ["status", "method", "booking"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Payment.objects.none()
        user = self.request.user
        qs = Payment.objects.select_related("booking")
        if IsPlatformAdmin().has_permission(self.request, self):
            return qs
        return qs.filter(Q(payer=user) | Q(booking__worker__user=user))

    @extend_schema(
        tags=["payments"], request=PaymentCreateSerializer, responses={201: PaymentSerializer},
        summary="Customer records payment for a completed booking (cash only in Stage 1). "
        "Amount is taken from the booking's locked price.",
    )
    def create(self, request):
        if not IsCustomer().has_permission(request, self):
            return Response({"detail": IsCustomer.message}, status=status.HTTP_403_FORBIDDEN)
        serializer = PaymentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payment = services.record_payment(
            serializer.validated_data["booking"], request.user, serializer.validated_data["method"]
        )
        return Response(PaymentSerializer(payment).data, status=status.HTTP_201_CREATED)

    @extend_schema(tags=["payments"], request=None, responses={200: PaymentSerializer},
                   summary="Worker confirms they received the cash.")
    @action(detail=True, methods=["post"])
    def confirm(self, request, pk=None):
        payment = self.get_object()
        payment = services.confirm_cash_payment(payment, request.user)
        return Response(PaymentSerializer(payment).data)


class WorkerEarningsView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["payments"], responses={200: EarningsSummarySerializer},
                   summary="Worker: earnings and commission summary")
    def get(self, request):
        worker = request.user.worker_profile
        qs = Commission.objects.filter(worker=worker)
        agg = qs.aggregate(
            n=Count("id"), gross=Sum("gross_amount"), commission=Sum("commission_amount"),
            net=Sum("worker_earning"),
            pending=Sum("commission_amount", filter=Q(status=Commission.Status.PENDING)),
        )
        zero = Decimal("0.00")
        data = {
            "completed_jobs": agg["n"],
            "gross_amount": agg["gross"] or zero,
            "commission_amount": agg["commission"] or zero,
            "net_earnings": agg["net"] or zero,
            "commission_pending": agg["pending"] or zero,
            "recent": qs.select_related("worker__user")[:20],
        }
        return Response(EarningsSummarySerializer(data).data)
