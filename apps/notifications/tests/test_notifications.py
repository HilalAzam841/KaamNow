import pytest

from apps.notifications.models import Notification
from apps.notifications.services import notify
from conftest import client_for, data

pytestmark = pytest.mark.django_db
URL = "/api/v1/notifications/"


def test_list_mark_read_and_count(customer, make_customer):
    n1 = notify(customer, Notification.Type.SYSTEM, "Hello", "Welcome to KaamNow")
    notify(customer, Notification.Type.SYSTEM, "Second", "Another one")
    notify(make_customer(), Notification.Type.SYSTEM, "Other", "Not yours")
    c = client_for(customer)
    assert data(c.get(URL))["count"] == 2
    assert data(c.get(f"{URL}unread-count/"))["unread"] == 2
    resp = c.post(f"{URL}{n1.pk}/read/")
    assert data(resp)["is_read"] is True
    assert data(c.get(URL, {"is_read": "false"}))["count"] == 1
    assert data(c.post(f"{URL}read-all/"))["marked_read"] == 1
    assert data(c.get(f"{URL}unread-count/"))["unread"] == 0


def test_cannot_read_others_notification(customer, make_customer):
    n = notify(make_customer(), Notification.Type.SYSTEM, "Private", "secret")
    assert client_for(customer).post(f"{URL}{n.pk}/read/").status_code == 404


def test_booking_flow_generates_notifications(customer, worker, make_booking):
    make_booking(customer, worker)
    types = set(Notification.objects.filter(user=worker.user).values_list("type", flat=True))
    assert "offer_accepted" in types
