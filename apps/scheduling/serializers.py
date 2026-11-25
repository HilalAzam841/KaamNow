from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.catalog.models import ServiceCategory

from .models import TimeOff, WorkingHours


class WorkingHoursSerializer(serializers.ModelSerializer):
    start = serializers.TimeField(source="start_time", format="%H:%M")
    end = serializers.TimeField(source="end_time", format="%H:%M")

    class Meta:
        model = WorkingHours
        fields = ["weekday", "start", "end"]

    def validate(self, attrs):
        if attrs["end_time"] <= attrs["start_time"]:
            raise serializers.ValidationError({"end": _("The end must be after the start.")})
        return attrs


class TimeOffSerializer(serializers.ModelSerializer):
    class Meta:
        model = TimeOff
        fields = ["id", "start_date", "end_date", "reason"]
        read_only_fields = ["id"]

    def validate(self, attrs):
        if attrs["end_date"] < attrs["start_date"]:
            raise serializers.ValidationError({"end_date": _("The end must be after the start.")})
        if attrs["end_date"] < timezone.localdate():
            raise serializers.ValidationError({"end_date": _("The end is in the past.")})
        if (attrs["end_date"] - attrs["start_date"]).days > 90:
            raise serializers.ValidationError({"end_date": _("Time off can be at most 90 days at once.")})
        return attrs


class ScheduleSerializer(serializers.Serializer):
    hours = WorkingHoursSerializer(many=True, help_text="One row per working day; leave a day out for a day off. "
                                                         "An empty list means available any time.")
    time_off = TimeOffSerializer(many=True, read_only=True)

    def validate_hours(self, rows):
        days = [r["weekday"] for r in rows]
        if len(days) != len(set(days)):
            raise serializers.ValidationError(_("Each day can appear only once."))
        return rows


class SlotQuerySerializer(serializers.Serializer):
    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.filter(is_active=True))
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-180, max_value=180)
    date = serializers.DateField()

    def validate_date(self, value):
        today = timezone.localdate()
        if value < today or (value - today).days > 60:
            raise serializers.ValidationError(_("Choose a day within the next 60 days."))
        return value


class SlotSerializer(serializers.Serializer):
    start = serializers.DateTimeField()
    end = serializers.DateTimeField()
    free_workers = serializers.IntegerField()
