import json
from unittest import mock

import pytest

from apps.notifications import fcm
from apps.notifications.models import DeviceToken, Notification
from apps.notifications.services import notify
from apps.notifications.tasks import send_push
from conftest import client_for, data

pytestmark = pytest.mark.django_db
DEVICES = "/api/v1/notifications/devices/"
TOKEN = "fcm-token-" + "a" * 40


@pytest.fixture
def fcm_on(settings):
    settings.FCM_PROJECT_ID = "kaamnow-test"
    settings.FCM_CREDENTIALS_FILE = "/secure/firebase.json"
    with mock.patch("apps.notifications.fcm._access_token", return_value="oauth-token"):
        yield


def fcm_response(status_code, error_status=None, error_code=None):
    body = {}
    if error_status:
        body = {"error": {"status": error_status, "details": [{"errorCode": error_code}] if error_code else []}}
    resp = mock.Mock(status_code=status_code, text=json.dumps(body))
    resp.json.return_value = body
    return resp


class TestDevices:
    def test_register_and_unregister(self, customer):
        c = client_for(customer)
        resp = c.post(DEVICES, {"token": TOKEN, "platform": "android"})
        assert resp.status_code == 201
        assert DeviceToken.objects.get(token=TOKEN).user == customer
        assert c.post(DEVICES, {"token": TOKEN}).status_code == 201  # re-register is idempotent
        assert DeviceToken.objects.count() == 1
        assert data(c.delete(DEVICES, {"token": TOKEN}))["deleted"] == 1

    def test_token_moves_to_new_account_on_same_device(self, customer, make_customer):
        client_for(customer).post(DEVICES, {"token": TOKEN})
        other = make_customer()
        client_for(other).post(DEVICES, {"token": TOKEN})
        assert DeviceToken.objects.get(token=TOKEN).user == other

    def test_cannot_delete_someone_elses_token(self, customer, make_customer):
        client_for(customer).post(DEVICES, {"token": TOKEN})
        assert data(client_for(make_customer()).delete(DEVICES, {"token": TOKEN}))["deleted"] == 0

    def test_validation_and_auth(self, api, customer):
        assert client_for(customer).post(DEVICES, {"token": "short"}).status_code == 400
        assert api.post(DEVICES, {"token": TOKEN}).status_code == 401


class TestFCM:
    def test_message_format(self):
        msg = fcm.build_message("tok", "Title", "Body", {"booking_id": 5, "type": "offer_accepted"})
        assert msg["message"]["token"] == "tok"
        assert msg["message"]["data"] == {"booking_id": "5", "type": "offer_accepted"}
        assert msg["message"]["android"]["priority"] == "high"

    def test_notify_sends_push_to_active_devices(self, customer, fcm_on, django_capture_on_commit_callbacks):
        DeviceToken.objects.create(user=customer, token=TOKEN)
        DeviceToken.objects.create(user=customer, token=TOKEN + "x", is_active=False)
        with mock.patch("apps.notifications.fcm.requests.post", return_value=fcm_response(200)) as post, \
                django_capture_on_commit_callbacks(execute=True):
            n = notify(customer, Notification.Type.SYSTEM, "Hello", "World", {"x": 1})
        assert post.call_count == 1
        call = post.call_args
        assert call.args[0] == "https://fcm.googleapis.com/v1/projects/kaamnow-test/messages:send"
        assert call.kwargs["headers"]["Authorization"] == "Bearer oauth-token"
        sent = call.kwargs["json"]["message"]
        assert sent["token"] == TOKEN and sent["notification"] == {"title": "Hello", "body": "World"}
        assert sent["data"]["notification_id"] == str(n.pk) and sent["data"]["type"] == "system"

    def test_dead_tokens_deactivated(self, customer, fcm_on):
        DeviceToken.objects.create(user=customer, token=TOKEN)
        with mock.patch("apps.notifications.fcm.requests.post",
                        return_value=fcm_response(404, "NOT_FOUND", "UNREGISTERED")):
            result = send_push(customer.pk, "t", "b", {})
        assert result == {"sent": 0, "deactivated": 1, "failed": 0}
        assert not DeviceToken.objects.get(token=TOKEN).is_active

    def test_transient_failure_retries(self, customer, fcm_on):
        from celery.exceptions import Retry

        DeviceToken.objects.create(user=customer, token=TOKEN)
        with mock.patch("apps.notifications.fcm.requests.post", return_value=fcm_response(503, "UNAVAILABLE")), \
                mock.patch.object(send_push, "retry", side_effect=Retry()):
            with pytest.raises(Retry):
                send_push(customer.pk, "t", "b", {})
        assert DeviceToken.objects.get(token=TOKEN).is_active

    def test_without_fcm_config_only_history_is_kept(self, customer, settings):
        settings.FCM_PROJECT_ID = ""
        DeviceToken.objects.create(user=customer, token=TOKEN)
        with mock.patch("apps.notifications.fcm.requests.post") as post:
            notify(customer, Notification.Type.SYSTEM, "Hello", "World")
        post.assert_not_called()
        assert Notification.objects.filter(user=customer).count() == 1
