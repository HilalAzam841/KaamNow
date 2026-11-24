from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.utils import timezone
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError
from apps.common.geo import haversine_km
from apps.common.realtime import broadcast_to_booking

from .models import BookingLocation


def _eta_minutes(distance_km, speed_kmh):
    speed = float(speed_kmh) if speed_kmh and float(speed_kmh) >= 5 else settings.KAAMNOW["AVERAGE_CITY_SPEED_KMH"]
    return max(1, round(distance_km / speed * 60)) if distance_km > 0.05 else 0


def describe(location, booking):
    distance = round(
        haversine_km(location.latitude, location.longitude, booking.request.latitude, booking.request.longitude), 2
    )
    return {
        "latitude": str(location.latitude),
        "longitude": str(location.longitude),
        "accuracy_m": str(location.accuracy_m) if location.accuracy_m is not None else None,
        "heading": str(location.heading) if location.heading is not None else None,
        "speed_kmh": str(location.speed_kmh) if location.speed_kmh is not None else None,
        "recorded_at": location.recorded_at,
        "distance_to_customer_km": distance,
        "eta_minutes": _eta_minutes(distance, location.speed_kmh),
        "booking_status": booking.status,
    }


def record_location(booking, user, latitude, longitude, accuracy_m=None, heading=None, speed_kmh=None):
    if booking.worker.user_id != user.pk:
        raise BusinessRuleError("Only the assigned worker can share location.", status_code=403)
    if not booking.is_active:
        raise BusinessRuleError("Location sharing is only available during an active booking.",
                                status_code=http_status.HTTP_409_CONFLICT)
    lat, lng = Decimal(str(latitude)), Decimal(str(longitude))
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        raise BusinessRuleError("Invalid coordinates.")
    location = BookingLocation.objects.create(
        booking=booking, worker=booking.worker, latitude=lat.quantize(Decimal("0.000001")),
        longitude=lng.quantize(Decimal("0.000001")), accuracy_m=accuracy_m, heading=heading, speed_kmh=speed_kmh,
    )
    data = describe(location, booking)
    broadcast_to_booking(booking.pk, "location.update", data)
    return location, data


def latest_location(booking, user, trail=20):
    """Latest point plus a short trail. Customers only see it while the booking is active."""
    is_worker = booking.worker.user_id == user.pk
    if not is_worker and not booking.is_active:
        raise BusinessRuleError("Live location is only shared during an active booking.",
                                status_code=http_status.HTTP_409_CONFLICT)
    points = list(BookingLocation.objects.filter(booking=booking)[:trail])
    if not points:
        return {"latest": None, "trail": []}
    return {
        "latest": describe(points[0], booking),
        "trail": [{"latitude": str(p.latitude), "longitude": str(p.longitude), "recorded_at": p.recorded_at}
                  for p in points],
    }


def purge_old_locations():
    cutoff = timezone.now() - timedelta(days=settings.KAAMNOW["LOCATION_RETENTION_DAYS"])
    deleted, _ = BookingLocation.objects.filter(recorded_at__lt=cutoff).delete()
    return deleted
