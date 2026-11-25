"""Fixtures shared by the billing tests."""

import pytest

from apps.billing.models import Payment
from conftest import client_for, data, jazzcash_callback

PAY = "/api/v1/payments/"
JC_CB = "/api/v1/payments/callbacks/jazzcash/"


@pytest.fixture
def paid_cash(customer, worker, completed_booking_factory):
    """A job paid in cash: the worker holds the money and owes 10% commission."""

    def _make(price="2000"):
        booking = completed_booking_factory(customer, worker, price)
        payment = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}))
        assert client_for(worker.user).post(f"{PAY}{payment['id']}/confirm/").status_code == 200
        return booking

    return _make


@pytest.fixture
def paid_online(api, customer, worker, completed_booking_factory, gateways):
    """A job paid with JazzCash: KaamNow holds the money and owes the worker 90%."""

    def _make(price="2000"):
        booking = completed_booking_factory(customer, worker, price)
        body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash"}))
        payment = Payment.objects.get(pk=body["id"])
        assert api.post(JC_CB, jazzcash_callback(payment), format="multipart").status_code == 200
        return booking

    return _make
