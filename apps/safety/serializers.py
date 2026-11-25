from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.common.validators import normalize_pk_phone

from .models import EmergencyContact, SosAlert


class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ["id", "name", "phone", "created_at"]
        read_only_fields = ["id", "created_at"]
        extra_kwargs = {"phone": {"validators": []}}

    def validate_name(self, value):
        value = value.strip()
        if len(value) < 2:
            raise serializers.ValidationError(_("Enter a name."))
        return value

    def validate_phone(self, value):
        try:
            return normalize_pk_phone(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages) from exc


class SosRaiseSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90, required=False)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180,
                                         required=False)
    note = serializers.CharField(max_length=500, required=False, allow_blank=True, default="")

    def validate(self, attrs):
        if ("latitude" in attrs) != ("longitude" in attrs):
            raise serializers.ValidationError(_("Send both latitude and longitude, or neither."))
        return attrs


class SosAlertSerializer(serializers.ModelSerializer):
    """What the person who pressed SOS sees."""

    class Meta:
        model = SosAlert
        fields = ["id", "booking", "status", "contacts_texted", "created_at", "handled_at"]
        read_only_fields = fields


class ShareStartSerializer(serializers.Serializer):
    send_to_contacts = serializers.BooleanField(required=False, default=False,
                                                help_text="Also text the link to your emergency contacts.")


class ShareSerializer(serializers.Serializer):
    url = serializers.CharField(help_text="Shown once. Sharing again makes a new link and turns this one off.")
    expires_at = serializers.DateTimeField()
    contacts_texted = serializers.IntegerField()


class SharedWorkerSerializer(serializers.Serializer):
    name = serializers.CharField()
    is_verified = serializers.BooleanField()
    average_rating = serializers.CharField()
    completed_jobs_count = serializers.IntegerField()


class SharedLocationSerializer(serializers.Serializer):
    latitude = serializers.CharField()
    longitude = serializers.CharField()
    recorded_at = serializers.DateTimeField()


class SharedJobSerializer(serializers.Serializer):
    """Public view of a shared job: no phone numbers, no address, no exact customer location."""

    title = serializers.CharField()
    category_name = serializers.CharField()
    area = serializers.CharField()
    status = serializers.CharField()
    preferred_time = serializers.DateTimeField()
    duration_minutes = serializers.IntegerField()
    shared_by = serializers.ChoiceField(choices=SosAlert.Role.choices)
    customer_name = serializers.CharField()
    worker = SharedWorkerSerializer()
    on_the_way_at = serializers.DateTimeField(allow_null=True)
    arrived_at = serializers.DateTimeField(allow_null=True)
    started_at = serializers.DateTimeField(allow_null=True)
    completed_at = serializers.DateTimeField(allow_null=True)
    worker_location = SharedLocationSerializer(allow_null=True, help_text="Only while the worker is on the way.")
    expires_at = serializers.DateTimeField()


class AdminSosAlertSerializer(serializers.ModelSerializer):
    """Everything an admin needs to act fast, including both phone numbers and the address."""

    booking_title = serializers.CharField(source="booking.request.title", read_only=True)
    booking_status = serializers.CharField(source="booking.status", read_only=True)
    address = serializers.CharField(source="booking.request.address", read_only=True)
    raised_by_name = serializers.CharField(source="raised_by.full_name", read_only=True)
    raised_by_phone = serializers.CharField(source="raised_by.phone", read_only=True)
    other_party = serializers.SerializerMethodField()
    latest_worker_location = serializers.SerializerMethodField()
    handled_by_name = serializers.CharField(source="handled_by.full_name", read_only=True, default=None)

    class Meta:
        model = SosAlert
        fields = [
            "id", "booking", "booking_title", "booking_status", "address", "role", "raised_by", "raised_by_name",
            "raised_by_phone", "other_party", "latitude", "longitude", "latest_worker_location", "note", "status",
            "contacts_texted", "handled_by_name", "handled_at", "admin_note", "created_at",
        ]
        read_only_fields = fields

    def get_other_party(self, obj) -> dict:
        b = obj.booking
        other = b.customer if obj.role == SosAlert.Role.WORKER else b.worker.user
        return {"name": other.full_name, "phone": other.phone,
                "role": "customer" if obj.role == SosAlert.Role.WORKER else "worker"}

    def get_latest_worker_location(self, obj) -> dict | None:
        from apps.tracking.models import BookingLocation

        p = BookingLocation.objects.filter(booking_id=obj.booking_id).first()
        return None if p is None else {"latitude": str(p.latitude), "longitude": str(p.longitude),
                                       "recorded_at": p.recorded_at}


class HandleSosSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=[SosAlert.Status.ACKNOWLEDGED.value, SosAlert.Status.RESOLVED.value])
    note = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")
