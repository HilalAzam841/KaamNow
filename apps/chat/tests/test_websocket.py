"""WebSocket tests for chat, live location and status events (real ASGI app, in-memory channel layer)."""

import pytest
from asgiref.sync import sync_to_async
from channels.testing import WebsocketCommunicator
from rest_framework_simplejwt.tokens import AccessToken

from apps.jobs.models import Booking
from config.asgi import application

pytestmark = [pytest.mark.django_db(transaction=True), pytest.mark.asyncio]

ORIGIN = [(b"origin", b"http://localhost")]


def ws(booking_id, user=None, token=None):
    if user is not None:
        token = str(AccessToken.for_user(user))
    path = f"/ws/bookings/{booking_id}/" + (f"?token={token}" if token else "")
    return WebsocketCommunicator(application, path, headers=ORIGIN)


@pytest.fixture
def booking(customer, worker, make_booking):
    return make_booking(customer, worker)


async def test_rejects_anonymous_and_bad_token(booking):
    comm = ws(booking.pk)
    connected, code = await comm.connect()
    assert not connected and code == 4401
    comm = ws(booking.pk, token="not-a-jwt")
    connected, code = await comm.connect()
    assert not connected and code == 4401


async def test_rejects_non_participant(booking, make_customer):
    outsider = await sync_to_async(make_customer)()
    comm = ws(booking.pk, user=outsider)
    connected, code = await comm.connect()
    assert not connected and code == 4404


async def test_rejects_suspended_user(booking, customer):
    customer.is_suspended = True
    await sync_to_async(customer.save)()
    connected, code = await ws(booking.pk, user=customer).connect()
    assert not connected and code == 4401


async def test_rejects_foreign_origin(booking, customer):
    comm = WebsocketCommunicator(application, f"/ws/bookings/{booking.pk}/?token={AccessToken.for_user(customer)}",
                                 headers=[(b"origin", b"https://evil.example")])
    connected, _ = await comm.connect()
    assert not connected


async def test_chat_round_trip(booking, customer, worker):
    c, w = ws(booking.pk, user=customer), ws(booking.pk, user=worker.user)
    assert (await c.connect())[0] and (await w.connect())[0]

    await c.send_json_to({"type": "chat.message", "body": "Gate code is 1234"})
    for comm in (c, w):
        event = await comm.receive_json_from(timeout=3)
        assert event["type"] == "chat.message"
        assert event["data"]["body"] == "Gate code is 1234"
        assert event["data"]["sender"] == customer.pk

    await w.send_json_to({"type": "chat.read"})
    for comm in (c, w):
        event = await comm.receive_json_from(timeout=3)
        assert event["type"] == "chat.read" and event["data"]["reader"] == worker.user.pk

    await c.send_json_to({"type": "ping"})
    assert await c.receive_json_from() == {"type": "pong"}
    await c.disconnect()
    await w.disconnect()


async def test_rest_message_is_pushed_to_socket(booking, customer, worker):
    from conftest import client_for

    w = ws(booking.pk, user=worker.user)
    assert (await w.connect())[0]
    resp = await sync_to_async(client_for(customer).post)(f"/api/v1/bookings/{booking.pk}/messages/",
                                                          {"body": "Sent over REST"})
    assert resp.status_code == 201
    event = await w.receive_json_from(timeout=3)
    assert event["type"] == "chat.message" and event["data"]["body"] == "Sent over REST"
    await w.disconnect()


async def test_live_location_and_status_events(booking, customer, worker):
    from apps.jobs.services import update_booking_status

    c, w = ws(booking.pk, user=customer), ws(booking.pk, user=worker.user)
    assert (await c.connect())[0] and (await w.connect())[0]

    await sync_to_async(update_booking_status)(booking, worker.user, Booking.Status.ON_THE_WAY)
    event = await c.receive_json_from(timeout=3)
    assert event["type"] == "booking.status" and event["data"]["to"] == "on_the_way"
    await w.receive_json_from(timeout=3)

    await w.send_json_to({"type": "location.update", "latitude": 31.52, "longitude": 74.344, "speed_kmh": 25})
    event = await c.receive_json_from(timeout=3)
    assert event["type"] == "location.update"
    assert event["data"]["latitude"] == "31.520000"
    assert event["data"]["distance_to_customer_km"] == pytest.approx(1.11, abs=0.05)

    # Customers cannot fake the worker's location.
    await w.receive_json_from(timeout=3)
    await c.send_json_to({"type": "location.update", "latitude": 31.0, "longitude": 74.0})
    error = await c.receive_json_from(timeout=3)
    assert error["type"] == "error" and "assigned worker" in error["message"]
    assert await c.receive_nothing(timeout=0.3)
    await c.disconnect()
    await w.disconnect()


async def test_invalid_messages(booking, customer):
    c = ws(booking.pk, user=customer)
    assert (await c.connect())[0]
    await c.send_json_to({"type": "nope"})
    assert (await c.receive_json_from())["type"] == "error"
    await c.send_json_to({"type": "chat.message", "body": ""})
    assert (await c.receive_json_from())["message"] == "Message cannot be empty."
    await c.disconnect()


async def test_events_are_isolated_per_booking(customer, worker, make_booking):
    b1 = await sync_to_async(make_booking)(customer, worker)
    b2 = await sync_to_async(make_booking)(customer, worker)
    c1, c2 = ws(b1.pk, user=customer), ws(b2.pk, user=customer)
    assert (await c1.connect())[0] and (await c2.connect())[0]
    await c1.send_json_to({"type": "chat.message", "body": "only for booking 1"})
    assert (await c1.receive_json_from(timeout=3))["data"]["booking"] == b1.pk
    assert await c2.receive_nothing(timeout=0.5)
    await c1.disconnect()
    await c2.disconnect()


async def test_accepts_cors_allowed_browser_origin(booking, customer, settings):
    settings.CORS_ALLOWED_ORIGINS = ["https://app.kaamnow.pk"]
    comm = WebsocketCommunicator(application, f"/ws/bookings/{booking.pk}/?token={AccessToken.for_user(customer)}",
                                 headers=[(b"origin", b"https://app.kaamnow.pk")])
    connected, _ = await comm.connect()
    assert connected
    await comm.disconnect()


async def test_accepts_native_client_without_origin(booking, customer):
    comm = WebsocketCommunicator(application, f"/ws/bookings/{booking.pk}/?token={AccessToken.for_user(customer)}")
    connected, _ = await comm.connect()
    assert connected
    await comm.disconnect()


async def test_rejects_malformed_origin(booking, customer):
    comm = WebsocketCommunicator(application, f"/ws/bookings/{booking.pk}/?token={AccessToken.for_user(customer)}",
                                 headers=[(b"origin", b"null")])
    connected, _ = await comm.connect()
    assert not connected
