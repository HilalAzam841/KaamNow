from django.db.models import Q
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.common.permissions import IsPlatformAdmin

from . import services
from .models import Tip
from .serializers import AdminTipSerializer, TipSerializer, TipSummarySerializer


@extend_schema(tags=["tips"])
class TipViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Tips you gave (customer) or got (worker). Give a tip with POST /bookings/{id}/tip/."""

    permission_classes = [IsAuthenticated]
    serializer_class = TipSerializer
    filterset_fields = ["status"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Tip.objects.none()
        user = self.request.user
        return Tip.objects.select_related("booking__request", "payment", "customer", "worker__user").filter(
            Q(customer=user) | Q(worker__user=user))

    @extend_schema(responses={200: TipSummarySerializer}, summary="A worker's paid tips: how many and the total.")
    @action(detail=False, methods=["get"])
    def summary(self, request):
        worker = getattr(request.user, "worker_profile", None)
        if worker is None:
            return Response(TipSummarySerializer({"count": 0, "total": 0}).data)
        return Response(TipSummarySerializer(services.summary(worker)).data)

    @extend_schema(request=None, responses={200: TipSerializer}, summary="Worker confirms a cash tip was received.")
    @action(detail=True, methods=["post"], url_path="confirm-cash")
    def confirm_cash(self, request, pk=None):
        tip = services.confirm_cash(self.get_object(), request.user)
        return Response(TipSerializer(self.get_queryset().get(pk=tip.pk)).data)

    @extend_schema(request=None, responses={200: TipSerializer},
                   summary="Worker says a cash tip never reached them. The tip is cancelled and the customer told.")
    @action(detail=True, methods=["post"], url_path="not-received")
    def not_received(self, request, pk=None):
        tip = services.decline_cash(self.get_object(), request.user)
        return Response(TipSerializer(self.get_queryset().get(pk=tip.pk)).data)


@extend_schema(tags=["admin"])
class AdminTipViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Every tip, newest first."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminTipSerializer
    filterset_fields = ["status", "method", "customer", "worker"]

    def get_queryset(self):
        return Tip.objects.select_related("booking__request", "payment", "customer", "worker__user")
