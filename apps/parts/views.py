import mimetypes

from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.jobs.access import booking_for_participant
from apps.jobs.models import Booking

from . import services
from .models import JobPart
from .serializers import JobPartCreateSerializer, JobPartSerializer, PartsSummarySerializer, RejectPartSerializer


def _stream(part):
    if not part.receipt:
        raise Http404
    content_type = mimetypes.guess_type(part.receipt.name)[0] or "application/octet-stream"
    response = FileResponse(part.receipt.open("rb"), content_type=content_type)
    response["Content-Disposition"] = f'inline; filename="part-receipt-{part.pk}"'
    response["Cache-Control"] = "private, no-store"
    return response


def _list(booking, user):
    booking.refresh_from_db(fields=["parts_amount"])
    return Response({
        "summary": PartsSummarySerializer(services.summary(booking, user)).data,
        "results": JobPartSerializer(JobPart.objects.filter(booking=booking), many=True).data,
    })


class BookingPartsView(APIView):
    """GET: parts and materials on a booking. POST: the worker adds one (multipart, receipt photo optional)."""

    parser_classes = [MultiPartParser, FormParser, JSONParser]

    @extend_schema(tags=["bookings"], responses={200: dict}, summary="Parts and materials on a booking")
    def get(self, request, booking_id):
        return _list(booking_for_participant(request.user, booking_id), request.user)

    @extend_schema(tags=["bookings"], request={"multipart/form-data": JobPartCreateSerializer},
                   responses={201: JobPartSerializer}, summary="Worker adds a part; the customer approves it")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        s = JobPartCreateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        part = services.add_part(booking, request.user, **s.validated_data)
        return Response(JobPartSerializer(part).data, status=status.HTTP_201_CREATED)


class BookingPartView(APIView):
    @extend_schema(tags=["bookings"], request=None, responses={204: None},
                   summary="Worker removes a part still waiting for the customer")
    def delete(self, request, booking_id, pk):
        booking = booking_for_participant(request.user, booking_id)
        services.delete_part(booking, request.user, get_object_or_404(JobPart, booking=booking, pk=pk))
        return Response(status=status.HTTP_204_NO_CONTENT)


class BookingPartApproveView(APIView):
    @extend_schema(tags=["bookings"], request=None, responses={200: JobPartSerializer},
                   summary="Customer approves a part (it is added to what they pay)")
    def post(self, request, booking_id, pk):
        booking = booking_for_participant(request.user, booking_id)
        part = services.approve(booking, request.user, get_object_or_404(JobPart, booking=booking, pk=pk))
        return Response(JobPartSerializer(part).data)


class BookingPartRejectView(APIView):
    @extend_schema(tags=["bookings"], request=RejectPartSerializer, responses={200: JobPartSerializer},
                   summary="Customer rejects a part, with a reason")
    def post(self, request, booking_id, pk):
        booking = booking_for_participant(request.user, booking_id)
        s = RejectPartSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        part = services.reject(booking, request.user, get_object_or_404(JobPart, booking=booking, pk=pk),
                               **s.validated_data)
        return Response(JobPartSerializer(part).data)


class BookingPartReceiptView(APIView):
    @extend_schema(tags=["bookings"], responses={(200, "image/jpeg"): bytes}, summary="The receipt photo")
    def get(self, request, booking_id, pk):
        booking = booking_for_participant(request.user, booking_id)
        return _stream(get_object_or_404(JobPart, booking=booking, pk=pk))


class AdminBookingPartsView(APIView):
    permission_classes = [IsPlatformAdmin]

    @extend_schema(tags=["admin"], responses={200: JobPartSerializer(many=True)})
    def get(self, request, booking_id):
        booking = get_object_or_404(Booking, pk=booking_id)
        return Response(JobPartSerializer(JobPart.objects.filter(booking=booking), many=True,
                                          context={"admin": True}).data)


class AdminBookingPartReceiptView(APIView):
    permission_classes = [IsPlatformAdmin]

    @extend_schema(tags=["admin"], responses={(200, "image/jpeg"): bytes}, summary="Opening a receipt is audited")
    def get(self, request, booking_id, pk):
        part = get_object_or_404(JobPart, booking_id=booking_id, pk=pk)
        audit(request.user, AuditLog.Action.PART_RECEIPT_VIEWED, part, request, booking_id=booking_id)
        return _stream(part)
