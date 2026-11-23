"""Geographic helpers.

Distance calculations are behind a small backend interface so that the
Haversine implementation used today can be swapped for PostGIS
(`django.contrib.gis` + `ST_DWithin`) without touching the callers.
"""

import math
from dataclasses import dataclass
from decimal import Decimal

from django.conf import settings

EARTH_RADIUS_KM = 6371.0088


def haversine_km(lat1, lng1, lat2, lng2) -> float:
    """Great-circle distance between two points in kilometres."""
    lat1, lng1, lat2, lng2 = (float(v) for v in (lat1, lng1, lat2, lng2))
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(min(1.0, a)))


@dataclass(frozen=True)
class BoundingBox:
    min_lat: float
    max_lat: float
    min_lng: float
    max_lng: float


def bounding_box(lat, lng, radius_km) -> BoundingBox:
    """Cheap lat/lng box that fully contains a circle of `radius_km`.

    Used as an indexed SQL pre-filter before the exact Haversine check.
    """
    lat, lng = float(lat), float(lng)
    d_lat = math.degrees(radius_km / EARTH_RADIUS_KM)
    cos_lat = max(math.cos(math.radians(lat)), 1e-6)
    d_lng = math.degrees(radius_km / (EARTH_RADIUS_KM * cos_lat))
    return BoundingBox(lat - d_lat, lat + d_lat, lng - d_lng, lng + d_lng)


class HaversineBackend:
    """Filters a WorkerProfile queryset to those whose service radius covers a point."""

    name = "haversine"

    def workers_covering_point(self, queryset, lat, lng):
        max_radius = settings.KAAMNOW["MAX_DISCOVERY_RADIUS_KM"]
        box = bounding_box(lat, lng, max_radius)
        candidates = queryset.filter(
            base_latitude__isnull=False,
            base_longitude__isnull=False,
            base_latitude__gte=Decimal(str(box.min_lat)),
            base_latitude__lte=Decimal(str(box.max_lat)),
            base_longitude__gte=Decimal(str(box.min_lng)),
            base_longitude__lte=Decimal(str(box.max_lng)),
        )
        results = []
        for worker in candidates:
            distance = haversine_km(lat, lng, worker.base_latitude, worker.base_longitude)
            if distance <= float(worker.service_radius_km) and distance <= max_radius:
                worker.distance_km = round(distance, 2)
                results.append(worker)
        results.sort(key=lambda w: w.distance_km)
        return results


def get_geo_backend():
    backend = settings.KAAMNOW.get("GEO_BACKEND", "haversine")
    if backend == "haversine":
        return HaversineBackend()
    raise NotImplementedError(f"Geo backend '{backend}' is not available yet.")
