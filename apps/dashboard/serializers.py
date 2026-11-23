from rest_framework import serializers

from apps.accounts.models import User

from .models import AuditLog


class RejectWorkerSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=500)


class SuspendUserSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)


class AdminUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "phone", "email", "full_name", "role", "is_active", "is_suspended", "suspended_reason",
                  "date_joined", "last_login"]
        read_only_fields = fields


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source="actor.full_name", default=None, read_only=True)

    class Meta:
        model = AuditLog
        fields = ["id", "actor", "actor_name", "action", "target_type", "target_id", "metadata", "ip_address",
                  "created_at"]
        read_only_fields = fields


class DateRangeSerializer(serializers.Serializer):
    date_from = serializers.DateField(required=False)
    date_to = serializers.DateField(required=False)

    def validate(self, attrs):
        if attrs.get("date_from") and attrs.get("date_to") and attrs["date_from"] > attrs["date_to"]:
            raise serializers.ValidationError("date_from must be before date_to.")
        return attrs
