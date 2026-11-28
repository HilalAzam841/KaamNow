from django.db.models import Q
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsPlatformAdmin
from apps.jobs.access import booking_for_participant

from . import services
from .models import GuaranteeClaim
from .serializers import (
    AcceptClaimSerializer,
    DeclineClaimSerializer,
    EscalateClaimSerializer,
    GuaranteeClaimSerializer,
    MakeClaimSerializer,
)


def _claims():
    return GuaranteeClaim.objects.select_related("booking__request", "customer", "worker__user", "complaint")


class BookingGuaranteeView(APIView):
    @extend_schema(tags=["guarantee"], request=MakeClaimSerializer, responses={201: GuaranteeClaimSerializer},
                   summary="Customer asks the worker for a free fix (within the guarantee period)")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        serializer = MakeClaimSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        claim = services.make_claim(booking, request.user, **serializer.validated_data)
        return Response(GuaranteeClaimSerializer(_claims().get(pk=claim.pk)).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["guarantee"])
class GuaranteeClaimViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Guarantee claims you made (customer) or that were made on your jobs (worker)."""

    permission_classes = [IsAuthenticated]
    serializer_class = GuaranteeClaimSerializer
    filterset_fields = ["status"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return GuaranteeClaim.objects.none()
        user = self.request.user
        return _claims().filter(Q(customer=user) | Q(worker__user=user))

    def _done(self, claim):
        return Response(GuaranteeClaimSerializer(_claims().get(pk=claim.pk)).data)

    @extend_schema(request=AcceptClaimSerializer, responses={200: GuaranteeClaimSerializer},
                   summary="Worker accepts and says when they will come back")
    @action(detail=True, methods=["post"])
    def accept(self, request, pk=None):
        s = AcceptClaimSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return self._done(services.accept(self.get_object(), request.user, **s.validated_data))

    @extend_schema(request=DeclineClaimSerializer, responses={200: GuaranteeClaimSerializer},
                   summary="Worker declines, with a reason the customer sees")
    @action(detail=True, methods=["post"])
    def decline(self, request, pk=None):
        s = DeclineClaimSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return self._done(services.decline(self.get_object(), request.user, **s.validated_data))

    @extend_schema(request=None, responses={200: GuaranteeClaimSerializer}, summary="Worker marks the fix done")
    @action(detail=True, methods=["post"], url_path="redo-done")
    def redo_done(self, request, pk=None):
        return self._done(services.mark_redo_done(self.get_object(), request.user))

    @extend_schema(request=None, responses={200: GuaranteeClaimSerializer},
                   summary="Customer confirms the problem is fixed")
    @action(detail=True, methods=["post"], url_path="confirm-fixed")
    def confirm_fixed(self, request, pk=None):
        return self._done(services.confirm_fixed(self.get_object(), request.user))

    @extend_schema(request=None, responses={200: GuaranteeClaimSerializer}, summary="Customer withdraws the claim")
    @action(detail=True, methods=["post"])
    def withdraw(self, request, pk=None):
        return self._done(services.withdraw(self.get_object(), request.user))

    @extend_schema(request=EscalateClaimSerializer, responses={200: GuaranteeClaimSerializer},
                   summary="Customer sends the claim to the KaamNow team (opens a complaint)")
    @action(detail=True, methods=["post"])
    def escalate(self, request, pk=None):
        s = EscalateClaimSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return self._done(services.escalate(self.get_object(), request.user, **s.validated_data))


@extend_schema(tags=["admin"])
class AdminGuaranteeClaimViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Every guarantee claim, newest first. Escalated claims are handled as complaints."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = GuaranteeClaimSerializer
    filterset_fields = ["status", "worker", "customer"]

    def get_queryset(self):
        return _claims()
