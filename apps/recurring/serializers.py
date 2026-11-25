from datetime import timedelta

from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.jobs.models import Booking

from .models import RecurringJob, RecurringVisit


class RecurringVisitSerializer(serializers.ModelSerializer):
    request_id = serializers.IntegerField(source="request.id", read_only=True, allow_null=True, default=None)
    booking_id = serializers.SerializerMethodField()

    class Meta:
        model = RecurringVisit
        fields = ["id", "scheduled_for", "outcome", "note", "request_id", "booking_id", "created_at"]
        read_only_fields = fields

    def get_booking_id(self, obj) -> int | None:
        booking = getattr(obj.request, "booking", None) if obj.request_id and hasattr(obj.request, "booking") else None
        return booking.pk if booking else None


class RecurringJobSerializer(serializers.ModelSerializer):
    """The customer's full view of their repeating job."""

    category_name = serializers.CharField(source="category.display_name", read_only=True)
    worker = serializers.SerializerMethodField()
    recent_visits = serializers.SerializerMethodField()

    class Meta:
        model = RecurringJob
        fields = [
            "id", "title", "description", "category", "category_name", "address", "area", "duration_minutes",
            "budget", "frequency", "next_visit", "status", "worker", "source_booking", "recent_visits", "created_at",
        ]
        read_only_fields = fields

    def get_worker(self, obj) -> dict | None:
        """The usual worker, or null when visits go to every worker nearby."""
        w = obj.worker
        return None if w is None else {"id": w.pk, "full_name": w.user.full_name}

    def get_recent_visits(self, obj) -> list[dict]:
        visits = obj.visits.select_related("request__booking")[:5]
        return RecurringVisitSerializer(visits, many=True).data


class RecurringJobForWorkerSerializer(serializers.ModelSerializer):
    """What the usual worker sees: no address or exact location until a visit is booked."""

    category_name = serializers.CharField(source="category.display_name", read_only=True)
    customer_name = serializers.SerializerMethodField()

    class Meta:
        model = RecurringJob
        fields = ["id", "title", "category", "category_name", "area", "duration_minutes", "budget", "frequency",
                  "next_visit", "status", "customer_name", "created_at"]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        return obj.customer.full_name.split(" ")[0]


def _validate_visit_time(value):
    now = timezone.now()
    if value <= now + timedelta(hours=2):
        raise serializers.ValidationError(_("The first visit must be at least two hours from now."))
    if value > now + timedelta(days=60):
        raise serializers.ValidationError(_("The first visit must be within the next 60 days."))
    return value


class RecurringFromBookingSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(
        queryset=Booking.objects.select_related("request__category", "worker__user"))
    frequency = serializers.ChoiceField(choices=RecurringJob.Frequency.choices)
    first_visit = serializers.DateTimeField(help_text="When the first repeat visit starts (2 hours to 60 days ahead).")

    def validate_first_visit(self, value):
        return _validate_visit_time(value)


class RecurringUpdateSerializer(serializers.Serializer):
    frequency = serializers.ChoiceField(choices=RecurringJob.Frequency.choices, required=False)
    next_visit = serializers.DateTimeField(required=False, help_text="Move the next visit (2 hours to 60 days ahead).")
    budget = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=0, required=False, allow_null=True)

    def validate_next_visit(self, value):
        return _validate_visit_time(value)
