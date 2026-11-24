from django.utils.translation import gettext as _
from rest_framework import serializers

from . import webpush
from .models import DeviceToken, Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "type", "title", "body", "data", "is_read", "read_at", "created_at"]
        read_only_fields = fields


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ["id", "token", "platform", "is_active", "created_at", "last_seen_at"]
        read_only_fields = ["id", "is_active", "created_at", "last_seen_at"]
        extra_kwargs = {"token": {"validators": []}}  # re-registration handled in the view

    def validate_token(self, value):
        value = value.strip()
        if len(value) < 20:
            raise serializers.ValidationError(_("Invalid device token."))
        return value


class DeviceTokenDeleteSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)


class WebPushKeysSerializer(serializers.Serializer):
    p256dh = serializers.CharField(max_length=100)
    auth = serializers.CharField(max_length=50)


class WebPushSubscribeSerializer(serializers.Serializer):
    """The browser's PushSubscription.toJSON(), as is."""

    endpoint = serializers.URLField(max_length=1000)
    keys = WebPushKeysSerializer()

    def validate(self, attrs):
        try:
            webpush.validate_subscription(attrs["endpoint"], attrs["keys"]["p256dh"], attrs["keys"]["auth"])
        except webpush.InvalidSubscription as exc:
            raise serializers.ValidationError({"endpoint": str(exc)}) from exc
        return attrs


class WebPushUnsubscribeSerializer(serializers.Serializer):
    endpoint = serializers.URLField(max_length=1000)
