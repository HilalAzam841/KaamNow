"""Booking concurrency tests.

These use real PostgreSQL transactions (transaction=True) and real threads so
that SELECT ... FOR UPDATE and the unique constraints are exercised exactly as
in production.
"""

import threading
from decimal import Decimal

import pytest
from django.db import connection

from apps.common.exceptions import BusinessRuleError
from apps.jobs.models import Booking, ServiceRequest
from apps.offers.models import WorkerOffer
from apps.offers.services import accept_offer

pytestmark = pytest.mark.django_db(transaction=True)


def run_concurrently(fns):
    barrier = threading.Barrier(len(fns))
    results = [None] * len(fns)

    def runner(i, fn):
        try:
            barrier.wait()
            results[i] = ("ok", fn())
        except BusinessRuleError as exc:
            results[i] = ("conflict", exc)
        except Exception as exc:  # pragma: no cover - surfaced by assertions
            results[i] = ("error", exc)
        finally:
            connection.close()

    threads = [threading.Thread(target=runner, args=(i, fn)) for i, fn in enumerate(fns)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=30)
    return results


def test_two_offers_accepted_simultaneously_creates_one_booking(customer, make_request, make_worker, make_offer):
    req = make_request(customer)
    offers = [make_offer(make_worker(), req, str(900 + i * 50)) for i in range(5)]

    results = run_concurrently([lambda o=o: accept_offer(o, customer) for o in offers])

    outcomes = [r[0] for r in results]
    assert outcomes.count("ok") == 1, results
    assert outcomes.count("conflict") == 4, results
    assert Booking.objects.filter(request=req).count() == 1
    assert WorkerOffer.objects.filter(request=req, status="accepted").count() == 1
    assert WorkerOffer.objects.filter(request=req, status="closed").count() == 4
    req.refresh_from_db()
    assert req.status == ServiceRequest.Status.BOOKED


def test_same_offer_double_accept_creates_one_booking(customer, worker, make_request, make_offer):
    req = make_request(customer)
    offer = make_offer(worker, req, "1000")

    results = run_concurrently([lambda: accept_offer(offer, customer) for _ in range(4)])

    assert [r[0] for r in results].count("ok") == 1, results
    assert Booking.objects.count() == 1
    assert Booking.objects.get().agreed_price == Decimal("1000.00")


def test_concurrent_duplicate_offers_by_same_worker(customer, worker, make_request):
    from apps.offers.services import create_offer

    req = make_request(customer)
    results = run_concurrently([
        lambda: create_offer(worker, req, price=Decimal("1000"), estimated_arrival_minutes=30) for _ in range(4)
    ])
    assert [r[0] for r in results].count("ok") == 1, results
    assert WorkerOffer.objects.filter(request=req, worker=worker).count() == 1


def test_offer_and_cancel_race(customer, worker, make_request, make_offer):
    """Accepting an offer while the customer cancels the request: exactly one wins."""
    from apps.jobs.services import cancel_service_request

    req = make_request(customer)
    offer = make_offer(worker, req, "1000")
    results = run_concurrently([
        lambda: accept_offer(offer, customer),
        lambda: cancel_service_request(req, customer, "changed my mind"),
    ])
    assert [r[0] for r in results].count("ok") == 1, results
    req.refresh_from_db()
    if req.status == ServiceRequest.Status.BOOKED:
        assert Booking.objects.filter(request=req).count() == 1
    else:
        assert req.status == ServiceRequest.Status.CANCELLED
        assert not Booking.objects.filter(request=req).exists()
