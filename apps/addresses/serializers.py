from django.utils.translation import gettext as _
from rest_framework import serializers

from .models import SavedAddress


class SavedAddressSerializer(serializers.ModelSerializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180)
    make_default = serializers.BooleanField(write_only=True, required=False, default=False,
                                            help_text="Use this address first when posting a job.")

    class Meta:
        model = SavedAddress
        fields = ["id", "label", "name", "address", "area", "latitude", "longitude", "is_default", "make_default",
                  "created_at", "updated_at"]
        read_only_fields = ["id", "is_default", "created_at", "updated_at"]

    def validate_address(self, value):
        value = value.strip()
        if len(value) < 5:
            raise serializers.ValidationError(_("Write the full address (house, street, block)."))
        return value

    def validate(self, attrs):
        label = attrs.get("label", getattr(self.instance, "label", None))
        name = attrs.get("name", getattr(self.instance, "name", "")).strip()
        if "name" in attrs:
            attrs["name"] = name
        if label == SavedAddress.Label.OTHER and not name:
            raise serializers.ValidationError({"name": _("Give this place a name, e.g. Ammi's house.")})
        return attrs
