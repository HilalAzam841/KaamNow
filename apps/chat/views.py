from drf_spectacular.utils import extend_schema
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.jobs.access import booking_for_participant

from . import services
from .models import ChatMessage
from .serializers import ChatMessageCreateSerializer, ChatMessageSerializer


class BookingMessagesView(generics.ListAPIView):
    """GET: conversation history (newest first). POST: send a message. Participants only."""

    serializer_class = ChatMessageSerializer

    def get_throttles(self):
        if self.request.method == "POST":
            self.throttle_scope = "chat"
        return super().get_throttles()

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ChatMessage.objects.none()
        booking = booking_for_participant(self.request.user, self.kwargs["booking_id"])
        return ChatMessage.objects.filter(booking=booking).order_by("-created_at", "-id")

    @extend_schema(tags=["chat"])
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(tags=["chat"], request=ChatMessageCreateSerializer, responses={201: ChatMessageSerializer})
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        serializer = ChatMessageCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message = services.send_message(booking, request.user, serializer.validated_data["body"])
        return Response(ChatMessageSerializer(message, context={"request": request}).data,
                        status=status.HTTP_201_CREATED)


class BookingMessagesReadView(APIView):
    @extend_schema(tags=["chat"], request=None, responses={200: dict},
                   summary="Mark the other party's messages as read")
    def post(self, request, booking_id):
        booking = booking_for_participant(request.user, booking_id)
        return Response({"marked_read": services.mark_read(booking, request.user)})
