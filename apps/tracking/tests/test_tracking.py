from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.jobs.models import Booking
from apps.tracking.models import BookingLocation
from apps.tracking.services import purge_old_locations
from conftest import advance_to, client_for, data

pytestmark = pytest.mark.django_db


def url(b):
    return f"/api/v1/bookings/{b.pk}/location/"


class TestTracking:
    def test_worker_shares_customer_tracks(self, customer, worker, make_booking):
        booking = advance_to(make_booking(customer, worker), Booking.Status.ON_THE_WAY)
        w = client_for(worker.user)
        # Job is at (31.51, 74.344). Worker ~5.6 km north.
        resp = w.post(url(booking), {"latitude": "31.560000", "longitude": "74.344000", "speed_kmh": "30"})
        assert resp.status_code == 201, resp.json()
        point = data(resp)
        assert point["distance_to_customer_km"] == pytest.approx(5.56, abs=0.05)
        assert point["eta_minutes"] == 11  # 5.56 km at 30 km/h
        w.post(url(booking), {"latitude": "31.520000", "longitude": "74.344000"})  # no speed: city average
        live = data(client_for(customer).get(url(booking)))
        assert live["latest"]["latitude"] == "31.520000"
        assert live["latest"]["eta_minutes"] == 3  # 1.1 km at 25 km/h
        assert len(live["trail"]) == 2

    def test_customer_cannot_share(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = client_for(customer).post(url(booking), {"latitude": "31.5", "longitude": "74.3"})
        assert resp.status_code == 403

    def test_outsiders_404(self, customer, worker, make_booking, make_customer, make_worker):
        booking = make_booking(customer, worker)
        assert client_for(make_customer()).get(url(booking)).status_code == 404
        assert client_for(make_worker().user).post(url(booking), {"latitude": "31.5", "longitude": "74.3"}).status_code == 404

    def test_not_after_completion(self, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        assert client_for(worker.user).post(url(booking), {"latitude": "31.5", "longitude": "74.3"}).status_code == 409
        assert client_for(customer).get(url(booking)).status_code == 409

    @pytest.mark.parametrize("payload", [
        {"latitude": "95", "longitude": "74"}, {"latitude": "31.5"}, {"latitude": "31.5", "longitude": "74", "speed_kmh": "-3"},
    ])
    def test_validation(self, customer, worker, make_booking, payload):
        booking = make_booking(customer, worker)
        assert client_for(worker.user).post(url(booking), payload).status_code == 400

    def test_empty(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        assert data(client_for(customer).get(url(booking))) == {"latest": None, "trail": []}

    def test_purge(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        old = BookingLocation.objects.create(booking=booking, worker=worker, latitude=Decimal("31.5"),
                                             longitude=Decimal("74.3"))
        BookingLocation.objects.filter(pk=old.pk).update(recorded_at=timezone.now() - timedelta(days=31))
        BookingLocation.objects.create(booking=booking, worker=worker, latitude=Decimal("31.5"),
                                       longitude=Decimal("74.3"))
        assert purge_old_locations() == 1
        assert BookingLocation.objects.count() == 1
