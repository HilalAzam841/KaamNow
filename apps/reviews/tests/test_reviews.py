from decimal import Decimal

import pytest

from apps.jobs.models import Booking
from apps.jobs.services import confirm_completion_by_customer
from conftest import advance_to, client_for, data

pytestmark = pytest.mark.django_db
URL = "/api/v1/reviews/"


def complete(booking, customer):
    booking = advance_to(booking, Booking.Status.IN_PROGRESS)
    return confirm_completion_by_customer(booking, customer)


class TestReviews:
    def test_review_updates_worker_rating(self, customer, make_customer, worker, make_booking):
        b1 = complete(make_booking(customer, worker), customer)
        other = make_customer()
        b2 = complete(make_booking(other, worker), other)
        assert client_for(customer).post(URL, {"booking": b1.pk, "rating": 5, "comment": "Excellent"}).status_code == 201
        assert client_for(other).post(URL, {"booking": b2.pk, "rating": 4}).status_code == 201
        worker.refresh_from_db()
        assert worker.average_rating == Decimal("4.50")
        assert worker.rating_count == 2

    def test_public_list(self, api, customer, worker, make_booking):
        b = complete(make_booking(customer, worker), customer)
        client_for(customer).post(URL, {"booking": b.pk, "rating": 5, "comment": "Great"})
        resp = api.get(f"/api/v1/workers/{worker.pk}/reviews/")
        assert resp.status_code == 200
        results = data(resp)["results"]
        assert results[0]["rating"] == 5
        assert results[0]["customer_name"] == "Ayesha"  # first name only

    def test_only_after_completion(self, customer, worker, make_booking):
        b = make_booking(customer, worker)
        assert client_for(customer).post(URL, {"booking": b.pk, "rating": 5}).status_code == 409

    def test_only_once(self, customer, worker, make_booking):
        b = complete(make_booking(customer, worker), customer)
        c = client_for(customer)
        assert c.post(URL, {"booking": b.pk, "rating": 5}).status_code == 201
        assert c.post(URL, {"booking": b.pk, "rating": 1}).status_code == 409

    @pytest.mark.parametrize("rating", [0, 6, -1])
    def test_rating_range(self, customer, worker, make_booking, rating):
        b = complete(make_booking(customer, worker), customer)
        assert client_for(customer).post(URL, {"booking": b.pk, "rating": rating}).status_code == 400

    def test_cannot_review_others_booking(self, customer, make_customer, worker, make_booking):
        b = complete(make_booking(customer, worker), customer)
        assert client_for(make_customer()).post(URL, {"booking": b.pk, "rating": 1}).status_code == 403

    def test_worker_cannot_review(self, customer, worker, make_booking):
        b = complete(make_booking(customer, worker), customer)
        assert client_for(worker.user).post(URL, {"booking": b.pk, "rating": 5}).status_code == 403
