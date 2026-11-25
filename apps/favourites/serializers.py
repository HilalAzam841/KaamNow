from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.accounts.serializers import PublicWorkerSerializer

from .services import public_workers


class FavouriteWorkerSerializer(PublicWorkerSerializer):
    is_favourite = serializers.SerializerMethodField()
    saved_at = serializers.DateTimeField(read_only=True, allow_null=True, default=None)
    last_booked_at = serializers.DateTimeField(read_only=True, allow_null=True, default=None)

    class Meta(PublicWorkerSerializer.Meta):
        fields = PublicWorkerSerializer.Meta.fields + ["is_favourite", "saved_at", "last_booked_at"]

    def get_is_favourite(self, obj) -> bool:
        return obj.pk in self.context.get("favourite_ids", set())


class AddFavouriteSerializer(serializers.Serializer):
    worker = serializers.IntegerField()

    def validate_worker(self, value):
        worker = public_workers().filter(pk=value).first()
        if worker is None:
            raise serializers.ValidationError(_("Worker not found."))
        return worker
