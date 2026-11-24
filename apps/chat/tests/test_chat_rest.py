from datetime import timedelta
from unittest import mock

import pytest
from django.utils import timezone

from apps.chat.models import ChatMessage
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from conftest import client_for, data

pytestmark = pytest.mark.django_db


def url(b, suffix=""):
    return f"/api/v1/bookings/{b.pk}/messages/{suffix}"


class TestChat:
    def test_conversation(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        c, w = client_for(customer), client_for(worker.user)
        resp = c.post(url(booking), {"body": "  Please bring a ladder  "})
        assert resp.status_code == 201
        assert data(resp)["body"] == "Please bring a ladder" and data(resp)["is_mine"] is True
        w.post(url(booking), {"body": "Sure, on my way"})
        msgs = data(w.get(url(booking)))["results"]
        assert [m["body"] for m in msgs] == ["Sure, on my way", "Please bring a ladder"]  # newest first
        assert [m["is_mine"] for m in msgs] == [True, False]

    def test_read_receipts(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        client_for(customer).post(url(booking), {"body": "Hello"})
        client_for(customer).post(url(booking), {"body": "Are you there?"})
        # The sender reading does not mark their own messages.
        assert data(client_for(customer).post(url(booking, "read/")))["marked_read"] == 0
        assert data(client_for(worker.user).post(url(booking, "read/")))["marked_read"] == 2
        assert ChatMessage.objects.filter(is_read=True).count() == 2

    def test_outsiders_get_404(self, customer, worker, make_booking, make_customer, make_worker, admin_user):
        booking = make_booking(customer, worker)
        client_for(customer).post(url(booking), {"body": "private"})
        for outsider in (make_customer(), make_worker().user, admin_user):
            client = client_for(outsider)
            assert client.get(url(booking)).status_code == 404
            assert client.post(url(booking), {"body": "hi"}).status_code == 404

    def test_validation(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        c = client_for(customer)
        assert c.post(url(booking), {"body": "   "}).status_code == 400
        assert c.post(url(booking), {"body": "x" * 2001}).status_code == 400

    def test_closed_after_cancellation(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        client_for(customer).post(f"/api/v1/bookings/{booking.pk}/cancel/", {"reason": "Changed plans"})
        assert client_for(customer).post(url(booking), {"body": "hello"}).status_code == 409
        assert client_for(customer).get(url(booking)).status_code == 200  # history stays readable

    def test_window_after_completion(self, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        assert client_for(customer).post(url(booking), {"body": "Thanks!"}).status_code == 201
        Booking.objects.filter(pk=booking.pk).update(completed_at=timezone.now() - timedelta(hours=49))
        assert client_for(customer).post(url(booking), {"body": "One more thing"}).status_code == 409

    def test_chat_push_is_not_stored_as_notification(self, customer, worker, make_booking,
                                                      django_capture_on_commit_callbacks):
        booking = make_booking(customer, worker)
        before = Notification.objects.count()
        with mock.patch("apps.chat.services.push_only") as push, django_capture_on_commit_callbacks(execute=True):
            client_for(customer).post(url(booking), {"body": "Hi"})
        assert Notification.objects.count() == before
        recipient = push.call_args.args[0]
        assert recipient == worker.user

    def test_chat_throttle(self, customer, worker, make_booking, monkeypatch):
        from rest_framework.throttling import SimpleRateThrottle

        monkeypatch.setitem(SimpleRateThrottle.THROTTLE_RATES, "chat", "2/min")
        booking = make_booking(customer, worker)
        codes = [client_for(customer).post(url(booking), {"body": f"m{i}"}).status_code for i in range(3)]
        assert codes == [201, 201, 429]
