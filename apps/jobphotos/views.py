import mimetypes

from django.http import FileResponse
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.jobs.access import booking_for_participant
from apps.jobs.models import Booking

from . import services
from .models import JobPhoto
from .serializers import JobPhotoCreateSerializer, JobPhotoSerializer, JobPhotoSummarySerializer


def _stream(photo):
    content_type = mimetypes.guess_type(photo.image.name)[0] or "application/octet-stream"
    response = FileResponse(photo.image.open("rb"), content_type=content_type)
    response["Content-Disposition"] = f'inline; filename="job-photo-{photo.pk}"'
    response["Cache-Control"] = "private, no-store"
    return response


class BookingPhotosView(APIView):
    """GET: before and after photos of a booking (customer or worker). POST: the worker adds one."""

    parser_classes = [MultiPartParser, FormParser]

    def get_throttles(self):
        if self.request.method == "POST":
            self.throttle_scope = "job_photos"
        return super().get_throttles()

    @extend_schema(tags=["bookings"], responses={200: dict}, summary="Before and after photos of a booking")
    def get(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        photos = JobPhoto.objects.filter(booking=booking)
        return Response({
            "summary": JobPhotoSummarySerializer(services.summary(booking, request.user)).data,
            "results": JobPhotoSerializer(photos, many=True).data,
        })

    @extend_schema(tags=["bookings"], request={"multipart/form-data": JobPhotoCreateSerializer},
                   responses={201: JobPhotoSerializer}, summary="Worker adds a before or after photo")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        serializer = JobPhotoCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        photo = services.add_photo(booking, request.user, **serializer.validated_data)
        return Response(JobPhotoSerializer(photo).data, status=status.HTTP_201_CREATED)


class BookingPhotoView(APIView):
    @extend_schema(tags=["bookings"], request=None, responses={204: None}, summary="Worker removes their photo")
    def delete(self, request, booking_id, pk):
        booking = booking_for_participant(request.user, booking_id)
        photo = get_object_or_404(JobPhoto, booking=booking, pk=pk)
        services.delete_photo(booking, request.user, photo)
        return Response(status=status.HTTP_204_NO_CONTENT)


class BookingPhotoFileView(APIView):
    @extend_schema(tags=["bookings"], responses={(200, "image/jpeg"): bytes}, summary="The photo itself")
    def get(self, request, booking_id, pk):
        booking = booking_for_participant(request.user, booking_id)
        return _stream(get_object_or_404(JobPhoto, booking=booking, pk=pk))


class AdminBookingPhotosView(APIView):
    """For disputes and complaints. Listing is not audited; opening a photo is."""

    permission_classes = [IsPlatformAdmin]

    @extend_schema(tags=["admin"], responses={200: JobPhotoSerializer(many=True)})
    def get(self, request, booking_id):
        booking = get_object_or_404(Booking, pk=booking_id)
        photos = JobPhoto.objects.filter(booking=booking)
        return Response(JobPhotoSerializer(photos, many=True, context={"admin": True}).data)


class AdminBookingPhotoFileView(APIView):
    permission_classes = [IsPlatformAdmin]

    @extend_schema(tags=["admin"], responses={(200, "image/jpeg"): bytes})
    def get(self, request, booking_id, pk):
        photo = get_object_or_404(JobPhoto, booking_id=booking_id, pk=pk)
        audit(request.user, AuditLog.Action.JOB_PHOTO_VIEWED, photo, request, booking_id=booking_id)
        return _stream(photo)
