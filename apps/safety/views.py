from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.jobs.access import booking_for_participant

from . import services
from .models import EmergencyContact, SosAlert
from .serializers import (
    AdminSosAlertSerializer,
    EmergencyContactSerializer,
    HandleSosSerializer,
    ShareSerializer,
    SharedJobSerializer,
    ShareStartSerializer,
    SosAlertSerializer,
    SosRaiseSerializer,
)


class EmergencyContactsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["safety"], responses={200: EmergencyContactSerializer(many=True)},
                   summary="Your emergency contacts (up to 3). They get an SMS when you press SOS.")
    def get(self, request):
        return Response(EmergencyContactSerializer(EmergencyContact.objects.filter(user=request.user), many=True).data)

    @extend_schema(tags=["safety"], request=EmergencyContactSerializer, responses={201: EmergencyContactSerializer},
                   summary="Add an emergency contact.")
    def post(self, request):
        s = EmergencyContactSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        contact = services.add_contact(request.user, s.validated_data["name"], s.validated_data["phone"])
        return Response(EmergencyContactSerializer(contact).data, status=status.HTTP_201_CREATED)


class EmergencyContactDetailView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["safety"], responses={204: None}, summary="Remove an emergency contact.")
    def delete(self, request, pk):
        get_object_or_404(EmergencyContact, pk=pk, user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class BookingSosView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "sos"

    @extend_schema(tags=["safety"], request=SosRaiseSerializer, responses={201: SosAlertSerializer, 200: SosAlertSerializer},
                   summary="Press SOS during a job (or up to an hour after). Admins are alerted and your emergency "
                           "contacts are texted a link. The other side is not told. Pressing again returns the same "
                           "open alert (200).")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        s = SosRaiseSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        alert, created = services.raise_sos(booking, request.user, **s.validated_data)
        return Response(SosAlertSerializer(alert).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class BookingShareView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["safety"], request=ShareStartSerializer, responses={201: ShareSerializer},
                   summary="Get a private link so family can follow this job. Sharing again replaces the old link.")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        s = ShareStartSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        share, url, texted = services.start_sharing(booking, request.user, **s.validated_data)
        return Response({"url": url, "expires_at": share.expires_at, "contacts_texted": texted},
                        status=status.HTTP_201_CREATED)

    @extend_schema(tags=["safety"], responses={204: None}, summary="Turn off your link for this job.")
    def delete(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        services.stop_sharing(booking, request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class SharedJobView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_scope = "share"

    @extend_schema(tags=["safety"], responses={200: SharedJobSerializer}, auth=[],
                   summary="Public: follow a shared job with its link. 404 when the link is wrong, off or expired.")
    def get(self, request, token):
        data = services.shared_job(token)
        if data is None:
            raise NotFound()
        return Response(SharedJobSerializer(data).data)


@extend_schema(tags=["admin"])
class AdminSosAlertViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """SOS alerts, newest first. Open ones need a call straight away."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminSosAlertSerializer
    filterset_fields = ["status", "role"]

    def get_queryset(self):
        return SosAlert.objects.select_related(
            "booking__request", "booking__customer", "booking__worker__user", "raised_by", "handled_by")

    @extend_schema(request=HandleSosSerializer, responses={200: AdminSosAlertSerializer})
    @action(detail=True, methods=["post"])
    def handle(self, request, pk=None):
        alert = self.get_object()
        s = HandleSosSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        alert = services.handle_sos(alert, request.user, **s.validated_data)
        audit(request.user, AuditLog.Action.SOS_HANDLED, alert, request, status=alert.status, booking=alert.booking_id)
        return Response(AdminSosAlertSerializer(alert).data)
