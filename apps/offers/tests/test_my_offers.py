import pytest

from apps.offers.models import WorkerOffer
from conftest import client_for, data

pytestmark = pytest.mark.django_db

URL = "/api/v1/offers/"


def test_worker_sees_only_own_offers_newest_first(customer, worker, make_worker, make_request, make_offer):
    first = make_offer(worker, make_request(customer))
    second = make_offer(worker, make_request(customer))
    make_offer(make_worker(), make_request(customer))  # someone else's

    resp = client_for(worker.user).get(URL)
    assert resp.status_code == 200
    body = data(resp)
    assert body["count"] == 2
    assert [o["id"] for o in body["results"]] == [second.pk, first.pk]


def test_status_filter(customer, worker, make_request, make_offer):
    pending = make_offer(worker, make_request(customer))
    withdrawn = make_offer(worker, make_request(customer))
    WorkerOffer.objects.filter(pk=withdrawn.pk).update(status=WorkerOffer.Status.WITHDRAWN)

    body = data(client_for(worker.user).get(URL, {"status": "pending"}))
    assert [o["id"] for o in body["results"]] == [pending.pk]


def test_unknown_status_is_400(worker):
    assert client_for(worker.user).get(URL, {"status": "bogus"}).status_code == 400


def test_customers_and_anonymous_are_refused(customer, api):
    assert client_for(customer).get(URL).status_code == 403
    assert api.get(URL).status_code == 401
