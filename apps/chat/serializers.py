from rest_framework import serializers

from .models import ChatMessage


class ChatMessageSerializer(serializers.ModelSerializer):
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = ChatMessage
        fields = ["id", "booking", "sender", "body", "is_read", "read_at", "is_mine", "created_at"]
        read_only_fields = fields

    def get_is_mine(self, obj) -> bool:
        request = self.context.get("request")
        return bool(request and obj.sender_id == request.user.pk)


class ChatMessageCreateSerializer(serializers.Serializer):
    body = serializers.CharField(max_length=2000, trim_whitespace=True)
