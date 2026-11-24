from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.jobs.access import booking_for_participant

from . import services
from .serializers import LiveLocationSerializer, LocationPointSerializer, LocationUpdateSerializer


class BookingLocationView(APIView):
    def get_throttles(self):
        if self.request.method == "POST":
            self.throttle_scope = "location"
        return super().get_throttles()

    @extend_schema(tags=["tracking"], request=LocationUpdateSerializer, responses={201: LocationPointSerializer},
                   summary="Worker shares current GPS position (active bookings only). Also pushed over WebSocket.")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        serializer = LocationUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        _, data = services.record_location(booking, request.user, **serializer.validated_data)
        return Response(data, status=status.HTTP_201_CREATED)

    @extend_schema(tags=["tracking"], responses={200: LiveLocationSerializer},
                   summary="Latest worker position, distance and ETA to the job, plus a short trail.")
    def get(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        return Response(services.latest_location(booking, request.user))
