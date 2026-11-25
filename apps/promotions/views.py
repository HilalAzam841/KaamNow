from django.utils.translation import gettext as _
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import BusinessRuleError
from apps.common.permissions import IsCustomer, IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from . import services
from .models import PromoCode
from .serializers import AdminPromoCodeSerializer, PromoCheckSerializer, QuoteSerializer, ReferralSummarySerializer


class PromoCheckView(APIView):
    permission_classes = [IsCustomer]
    throttle_scope = "promo"

    @extend_schema(tags=["promotions"], request=PromoCheckSerializer, responses={200: QuoteSerializer},
                   summary="Shows what the customer would pay for a booking with a promo code and/or their credit. "
                           "Errors with code `promo_invalid` say why a code cannot be used.")
    def post(self, request):
        serializer = PromoCheckSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        v = serializer.validated_data
        if v["booking"].customer_id != request.user.pk:
            raise BusinessRuleError(_("You can only check your own bookings."), status_code=403)
        q = services.quote(v["booking"], request.user, promo_code=v["promo_code"], use_credit=v["use_credit"])
        return Response(QuoteSerializer(q).data)


class ReferralSummaryView(APIView):
    @extend_schema(tags=["promotions"], responses={200: ReferralSummarySerializer},
                   summary="Your invite code, credit balance and invite rewards.")
    def get(self, request):
        return Response(ReferralSummarySerializer(services.summary(request.user)).data)


@extend_schema(tags=["admin"])
class AdminPromoCodeViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.CreateModelMixin,
                            mixins.UpdateModelMixin, viewsets.GenericViewSet):
    """Promo codes. There is no delete: switch a code off with `is_active: false` (its history stays)."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminPromoCodeSerializer
    filterset_fields = ["is_active", "kind", "category"]
    search_fields = ["code", "description"]

    def get_queryset(self):
        return services.promo_stats(PromoCode.objects.select_related("category")).order_by("-created_at")

    def perform_create(self, serializer):
        promo = serializer.save(created_by=self.request.user)
        audit(self.request.user, AuditLog.Action.PROMO_SAVED, promo, self.request, code=promo.code, created=True)

    def perform_update(self, serializer):
        promo = serializer.save()
        audit(self.request.user, AuditLog.Action.PROMO_SAVED, promo, self.request, code=promo.code,
              changed=sorted(serializer.validated_data))

    def create(self, request, *args, **kwargs):
        resp = super().create(request, *args, **kwargs)
        return self._fresh(resp.data["id"], status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        resp = super().update(request, *args, **kwargs)
        return self._fresh(resp.data["id"], status.HTTP_200_OK)

    def _fresh(self, pk, code):
        return Response(AdminPromoCodeSerializer(self.get_queryset().get(pk=pk)).data, status=code)
