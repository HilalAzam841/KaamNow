from django.utils.translation import gettext as _
from django.utils import timezone
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from rest_framework import status
from rest_framework.views import APIView

from apps.common.exceptions import BusinessRuleError

from . import webpush
from .models import DeviceToken, Notification, WebPushSubscription
from .serializers import (
    DeviceTokenDeleteSerializer,
    DeviceTokenSerializer,
    NotificationSerializer,
    WebPushSubscribeSerializer,
    WebPushUnsubscribeSerializer,
)
from .services import mark_read


@extend_schema_view(list=extend_schema(tags=["notifications"]))
class NotificationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    serializer_class = NotificationSerializer
    filterset_fields = ["is_read", "type"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user)

    @extend_schema(tags=["notifications"], request=None, responses={200: NotificationSerializer})
    @action(detail=True, methods=["post"])
    def read(self, request, pk=None):
        notification = mark_read(self.get_object())
        return Response(NotificationSerializer(notification).data)

    @extend_schema(tags=["notifications"], request=None, responses={200: None})
    @action(detail=False, methods=["post"], url_path="read-all")
    def read_all(self, request):
        updated = self.get_queryset().filter(is_read=False).update(is_read=True, read_at=timezone.now())
        return Response({"marked_read": updated})

    @extend_schema(tags=["notifications"], responses={200: None})
    @action(detail=False, methods=["get"], url_path="unread-count")
    def unread_count(self, request):
        return Response({"unread": self.get_queryset().filter(is_read=False).count()})


class DeviceTokenView(APIView):
    """Register (POST) or unregister (DELETE) this device's Firebase token for push notifications."""

    @extend_schema(tags=["notifications"], request=DeviceTokenSerializer, responses={201: DeviceTokenSerializer})
    def post(self, request):
        serializer = DeviceTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data["token"]
        # A token belongs to one device; if another account used it before, it moves to this user.
        device, _ = DeviceToken.objects.update_or_create(
            token=token,
            defaults={"user": request.user, "platform": serializer.validated_data.get("platform", "android"),
                      "is_active": True},
        )
        return Response(DeviceTokenSerializer(device).data, status=status.HTTP_201_CREATED)

    @extend_schema(tags=["notifications"], request=DeviceTokenDeleteSerializer, responses={200: dict})
    def delete(self, request):
        serializer = DeviceTokenDeleteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        deleted, _ = DeviceToken.objects.filter(user=request.user, token=serializer.validated_data["token"]).delete()
        return Response({"deleted": deleted})


class WebPushSubscribeView(APIView):
    """Turn on browser notifications for this browser (send PushSubscription.toJSON())."""

    @extend_schema(tags=["notifications"], request=WebPushSubscribeSerializer, responses={201: dict})
    def post(self, request):
        if not webpush.is_configured():
            raise BusinessRuleError(
                _("Browser notifications are not set up on this server."), status_code=status.HTTP_503_SERVICE_UNAVAILABLE
            )
        serializer = WebPushSubscribeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        # One browser, one subscription: if someone else used this browser before, it moves to this user.
        WebPushSubscription.objects.update_or_create(
            endpoint=data["endpoint"],
            defaults={
                "user": request.user,
                "p256dh": data["keys"]["p256dh"],
                "auth": data["keys"]["auth"],
                "user_agent": request.META.get("HTTP_USER_AGENT", "")[:255],
                "is_active": True,
            },
        )
        return Response({"subscribed": True}, status=status.HTTP_201_CREATED)


class WebPushUnsubscribeView(APIView):
    """Turn off browser notifications for this browser (also called on log out)."""

    @extend_schema(tags=["notifications"], request=WebPushUnsubscribeSerializer, responses={200: dict})
    def post(self, request):
        serializer = WebPushUnsubscribeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        deleted, _ = WebPushSubscription.objects.filter(
            user=request.user, endpoint=serializer.validated_data["endpoint"]
        ).delete()
        return Response({"unsubscribed": bool(deleted)})
