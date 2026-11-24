"""Standard web push: encryption (RFC 8291 test vector), VAPID, subscriptions and delivery."""

import json
from unittest import mock

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
from django.core.management import call_command

from apps.notifications import webpush
from apps.notifications.models import WebPushSubscription
from apps.notifications.services import notify
from apps.notifications.tasks import deep_link, send_web_push
from conftest import client_for, data

pytestmark = pytest.mark.django_db
SUBSCRIBE = "/api/v1/notifications/web-push/subscribe/"
UNSUBSCRIBE = "/api/v1/notifications/web-push/unsubscribe/"
ENDPOINT = "https://fcm.googleapis.com/fcm/send/abc123:APA91b-test"

d = webpush.b64url_decode

# RFC 8291, Appendix A.
RFC = {
    "plaintext": "V2hlbiBJIGdyb3cgdXAsIEkgd2FudCB0byBiZSBhIHdhdGVybWVsb24",
    "as_private": "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw",
    "as_public": "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8",
    "ua_private": "q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94",
    "ua_public": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
    "salt": "DGv6ra1nlYgDCS1FRnbzlw",
    "auth": "BTBZMqHH6r4Tts7J_aSIgg",
    "cek": "oIhVW04MRdy2XN9CiKLxTg",
    "nonce": "4h_95klXJ5E_qnoN",
}


def browser_keys():
    """A fake browser: its key pair and auth secret, like PushSubscription.getKey()."""
    private = ec.generate_private_key(ec.SECP256R1())
    public = private.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    auth = b"0123456789abcdef"
    return private, webpush.b64url_encode(public), webpush.b64url_encode(auth)


def browser_decrypt(body, ua_private, auth_b64):
    """What the browser does on receipt (RFC 8291 section 3, receiver side), written independently."""
    salt, rs, idlen = body[:16], int.from_bytes(body[16:20], "big"), body[20]
    as_public = body[21:21 + idlen]
    ciphertext = body[21 + idlen:]
    assert rs == 4096
    shared = ua_private.exchange(ec.ECDH(), ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), as_public))
    ua_public = ua_private.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    ikm = HKDF(hashes.SHA256(), 32, d(auth_b64), b"WebPush: info\x00" + ua_public + as_public).derive(shared)
    cek = HKDF(hashes.SHA256(), 16, salt, b"Content-Encoding: aes128gcm\x00").derive(ikm)
    nonce = HKDF(hashes.SHA256(), 12, salt, b"Content-Encoding: nonce\x00").derive(ikm)
    plain = AESGCM(cek).decrypt(nonce, ciphertext, None)
    assert plain.endswith(b"\x02")
    return plain[:-1]


@pytest.fixture
def vapid(settings):
    public, private = webpush.generate_vapid_keys()
    settings.WEBPUSH_VAPID_PUBLIC_KEY = public
    settings.WEBPUSH_VAPID_PRIVATE_KEY = private
    settings.WEBPUSH_SUBJECT = "mailto:support@kaamnow.pk"
    return public


def subscribe_body(endpoint=ENDPOINT):
    _, p256dh, auth = browser_keys()
    return {"endpoint": endpoint, "keys": {"p256dh": p256dh, "auth": auth}}


class TestEncryption:
    def test_matches_the_rfc_8291_example(self):
        sender = ec.derive_private_key(int.from_bytes(d(RFC["as_private"]), "big"), ec.SECP256R1())
        body = webpush.encrypt(d(RFC["plaintext"]), RFC["ua_public"], RFC["auth"], salt=d(RFC["salt"]), sender_key=sender)
        assert body[:16] == d(RFC["salt"])
        assert body[16:20] == (4096).to_bytes(4, "big")
        assert body[20] == 65 and body[21:86] == d(RFC["as_public"])
        # Decrypting with the RFC's content key and nonce proves the key derivation matches.
        assert AESGCM(d(RFC["cek"])).decrypt(d(RFC["nonce"]), body[86:], None) == d(RFC["plaintext"]) + b"\x02"
        ua_private = ec.derive_private_key(int.from_bytes(d(RFC["ua_private"]), "big"), ec.SECP256R1())
        assert browser_decrypt(body, ua_private, RFC["auth"]) == d(RFC["plaintext"])

    def test_round_trip_with_fresh_keys_and_urdu_text(self):
        ua_private, p256dh, auth = browser_keys()
        message = json.dumps({"title": "نئی پیشکش موصول ہوئی"}, ensure_ascii=False).encode()
        body = webpush.encrypt(message, p256dh, auth)
        assert browser_decrypt(body, ua_private, auth) == message
        assert webpush.encrypt(message, p256dh, auth)[:16] != body[:16], "salt is random per message"


class TestVapid:
    def test_authorization_header_is_a_valid_es256_token_for_the_push_service(self, vapid):
        header = webpush.vapid_authorization(ENDPOINT)
        token = header.split("t=")[1].split(",")[0]
        assert header.endswith(f"k={vapid}")
        public = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), d(vapid))
        claims = jwt.decode(token, public, algorithms=["ES256"], audience="https://fcm.googleapis.com")
        assert claims["sub"] == "mailto:support@kaamnow.pk"

    def test_generate_command_prints_a_matching_pair(self, capsys):
        call_command("generate_vapid_keys")
        out = dict(line.split("=", 1) for line in capsys.readouterr().out.split())
        private = ec.derive_private_key(int.from_bytes(d(out["WEBPUSH_VAPID_PRIVATE_KEY"]), "big"), ec.SECP256R1())
        public = private.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
        assert webpush.b64url_encode(public) == out["WEBPUSH_VAPID_PUBLIC_KEY"]


class TestSubscriptions:
    def test_subscribe_and_unsubscribe(self, vapid, customer):
        c = client_for(customer)
        assert c.post(SUBSCRIBE, subscribe_body(), format="json").status_code == 201
        assert WebPushSubscription.objects.get(endpoint=ENDPOINT).user == customer
        assert c.post(SUBSCRIBE, subscribe_body(), format="json").status_code == 201  # idempotent
        assert WebPushSubscription.objects.count() == 1
        assert data(c.post(UNSUBSCRIBE, {"endpoint": ENDPOINT}, format="json"))["unsubscribed"] is True
        assert not WebPushSubscription.objects.exists()

    def test_browser_moves_to_the_account_that_signed_in_last(self, vapid, customer, make_customer):
        client_for(customer).post(SUBSCRIBE, subscribe_body(), format="json")
        other = make_customer()
        client_for(other).post(SUBSCRIBE, subscribe_body(), format="json")
        assert WebPushSubscription.objects.get(endpoint=ENDPOINT).user == other

    def test_cannot_unsubscribe_someone_elses_browser(self, vapid, customer, make_customer):
        client_for(customer).post(SUBSCRIBE, subscribe_body(), format="json")
        assert data(client_for(make_customer()).post(UNSUBSCRIBE, {"endpoint": ENDPOINT}, format="json"))[
            "unsubscribed"] is False
        assert WebPushSubscription.objects.exists()

    @pytest.mark.parametrize("endpoint", [
        "http://fcm.googleapis.com/fcm/send/x",           # not https
        "https://evil.example.com/collect",              # not a push service
        "https://fcm.googleapis.com.evil.example/x",     # look-alike host
        "https://169.254.169.254/latest/meta-data",      # internal address
    ])
    def test_only_real_push_services_are_accepted(self, vapid, customer, endpoint):
        resp = client_for(customer).post(SUBSCRIBE, subscribe_body(endpoint), format="json")
        assert resp.status_code == 400
        assert not WebPushSubscription.objects.exists()

    def test_other_push_services_are_accepted(self, vapid, customer):
        for endpoint in ["https://updates.push.services.mozilla.com/wpush/v2/abc",
                         "https://web.push.apple.com/QAbc"]:
            assert client_for(customer).post(SUBSCRIBE, subscribe_body(endpoint), format="json").status_code == 201

    def test_bad_keys_are_refused(self, vapid, customer):
        body = {"endpoint": ENDPOINT, "keys": {"p256dh": "not-a-key", "auth": "short"}}
        assert client_for(customer).post(SUBSCRIBE, body, format="json").status_code == 400

    def test_needs_login_and_server_keys(self, api, settings, customer):
        assert api.post(SUBSCRIBE, subscribe_body(), format="json").status_code == 401
        settings.WEBPUSH_VAPID_PUBLIC_KEY = ""
        resp = client_for(customer).post(SUBSCRIBE, subscribe_body(), format="json")
        assert resp.status_code == 503

    def test_app_config_gives_the_public_key_only(self, api, vapid, settings):
        cfg = data(api.get("/api/v1/app/config/"))["web_push"]
        assert cfg == {"enabled": True, "public_key": vapid}
        assert settings.WEBPUSH_VAPID_PRIVATE_KEY not in json.dumps(data(api.get("/api/v1/app/config/")))


class TestDelivery:
    def _subscribe(self, user, endpoint=ENDPOINT):
        ua_private, p256dh, auth = browser_keys()
        sub = WebPushSubscription.objects.create(user=user, endpoint=endpoint, p256dh=p256dh, auth=auth)
        return sub, ua_private

    def test_alert_is_pushed_encrypted_in_the_users_language(self, vapid, make_customer, make_worker, make_request,
                                                             make_offer, django_capture_on_commit_callbacks):
        customer = make_customer(language="ur")
        sub, ua_private = self._subscribe(customer)
        req = make_request(customer)
        with mock.patch("apps.notifications.webpush.requests.post", return_value=mock.Mock(status_code=201)) as post, \
                django_capture_on_commit_callbacks(execute=True):
            make_offer(make_worker(), req, "1500")
        assert post.call_count == 1
        (url,), kwargs = post.call_args
        assert url == ENDPOINT
        assert kwargs["headers"]["Content-Encoding"] == "aes128gcm"
        assert kwargs["headers"]["Urgency"] == "high"
        assert kwargs["headers"]["Authorization"].startswith("vapid t=")
        payload = json.loads(browser_decrypt(kwargs["data"], ua_private, sub.auth))
        assert payload["title"] == "نئی پیشکش موصول ہوئی"
        assert payload["url"] == f"/#/requests/{req.pk}"

    def test_gone_subscriptions_are_turned_off(self, vapid, customer):
        sub, _ = self._subscribe(customer)
        with mock.patch("apps.notifications.webpush.requests.post", return_value=mock.Mock(status_code=410)):
            result = send_web_push(customer.pk, "t", "b", {"type": "system"})
        assert result["deactivated"] == 1
        sub.refresh_from_db()
        assert sub.is_active is False

    def test_no_push_without_keys_or_subscriptions(self, settings, customer, django_capture_on_commit_callbacks):
        settings.WEBPUSH_VAPID_PUBLIC_KEY = ""
        self._subscribe(customer)
        with mock.patch("apps.notifications.webpush.requests.post") as post, \
                django_capture_on_commit_callbacks(execute=True):
            notify(customer, "system", "Hello", "World")
        post.assert_not_called()

    def test_deep_links(self, customer, worker):
        assert deep_link(customer, {"type": "chat_message", "booking_id": 5}) == "/#/bookings/5/chat"
        assert deep_link(customer, {"type": "booking_status", "booking_id": 5}) == "/#/bookings/5"
        assert deep_link(customer, {"type": "new_offer", "request_id": 9}) == "/#/requests/9"
        assert deep_link(worker.user, {"type": "new_request", "request_id": 9}) == "/#/jobs/9"
        assert deep_link(customer, {"type": "complaint"}) == "/#/complaints"
        assert deep_link(customer, {"type": "system"}) == "/#/notifications"
