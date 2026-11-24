from rest_framework import serializers

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
            raise serializers.ValidationError("Invalid device token.")
        return value


class DeviceTokenDeleteSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)
