"""Phone verification and password reset by SMS code."""

import re
from datetime import timedelta

import pytest
import requests
from django.utils import timezone

from apps.accounts.models import PhoneCode, User
from apps.accounts.tasks import purge_old_phone_codes
from apps.common import sms
from conftest import PASSWORD, client_for, data, request_payload

pytestmark = pytest.mark.django_db

SEND = "/api/v1/auth/phone/send-code/"
VERIFY = "/api/v1/auth/phone/verify/"
RESET = "/api/v1/auth/password-reset/"
RESET_SMS = "/api/v1/auth/password-reset/sms-confirm/"
LOGIN = "/api/v1/auth/login/"


@pytest.fixture
def outbox(monkeypatch, settings):
    """Captures SMS instead of sending them; available as if a real SMS service were set up."""
    settings.DEBUG = True
    sent = []
    monkeypatch.setattr(sms, "send", lambda phone, text: sent.append((phone, text)))
    return sent


def code_in(text):
    return re.search(r"\b(\d{6})\b", text).group(1)


def error(resp):
    return resp.json()["error"]


class TestVerifyPhone:
    def test_send_and_verify(self, customer, outbox):
        c = client_for(customer)
        assert data(c.get("/api/v1/auth/me/"))["phone_verified"] is False
        resp = c.post(SEND)
        assert resp.status_code == 200
        assert data(resp)["resend_after"] == 60
        assert len(outbox) == 1 and outbox[0][0] == customer.phone
        code = code_in(outbox[0][1])
        # The code is never in an API response, and only its hash is stored.
        assert code not in resp.content.decode()
        assert code not in PhoneCode.objects.get().code_hash

        resp = c.post(VERIFY, {"code": code})
        assert resp.status_code == 200
        assert data(resp)["phone_verified"] is True
        customer.refresh_from_db()
        assert customer.phone_verified_at is not None
        assert error(c.post(SEND))["message"] == "Your phone number is already confirmed."

    def test_sms_is_written_in_the_users_language(self, make_customer, outbox):
        user = make_customer(language="ur")
        client_for(user).post(SEND)
        assert "کوڈ" in outbox[0][1]

    def test_wrong_code_counts_and_burns_after_five(self, customer, outbox):
        c = client_for(customer)
        c.post(SEND)
        code = code_in(outbox[0][1])
        wrong = "000000" if code != "000000" else "111111"
        for _ in range(5):
            assert c.post(VERIFY, {"code": wrong}).status_code == 400
        assert PhoneCode.objects.get().attempts == 5
        # Burned: even the right code no longer works.
        assert c.post(VERIFY, {"code": code}).status_code == 400
        customer.refresh_from_db()
        assert customer.phone_verified_at is None

    def test_expired_code_fails(self, customer, outbox):
        c = client_for(customer)
        c.post(SEND)
        PhoneCode.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        assert c.post(VERIFY, {"code": code_in(outbox[0][1])}).status_code == 400

    def test_resend_cooldown_and_only_newest_code_works(self, customer, outbox):
        c = client_for(customer)
        c.post(SEND)
        resp = c.post(SEND)
        assert resp.status_code == 429
        assert "wait" in error(resp)["message"]
        PhoneCode.objects.update(created_at=timezone.now() - timedelta(seconds=61))
        assert c.post(SEND).status_code == 200
        first, second = code_in(outbox[0][1]), code_in(outbox[1][1])
        if first != second:
            assert c.post(VERIFY, {"code": first}).status_code == 400
        assert c.post(VERIFY, {"code": second}).status_code == 200

    def test_daily_limit_per_number(self, customer, outbox):
        c = client_for(customer)
        for _ in range(5):
            assert c.post(SEND).status_code == 200
            PhoneCode.objects.update(created_at=timezone.now() - timedelta(minutes=5))
        resp = c.post(SEND)
        assert resp.status_code == 429
        assert "today" in error(resp)["message"]
        assert len(outbox) == 5

    def test_needs_login_and_sms(self, api, customer, settings):
        assert api.post(SEND).status_code == 401
        settings.DEBUG = False  # console backend in production: nothing would arrive
        resp = client_for(customer).post(SEND)
        assert resp.status_code == 503

    def test_failed_sms_says_so(self, customer, settings, monkeypatch):
        settings.DEBUG = True

        def boom(phone, text):
            raise sms.SmsError("provider down")

        monkeypatch.setattr(sms, "send", boom)
        resp = client_for(customer).post(SEND)
        assert resp.status_code == 503
        assert "could not send" in error(resp)["message"]


class TestRequiredBeforeWork:
    def test_unverified_customer_cannot_post_a_job(self, customer, category, settings):
        settings.PHONE_VERIFICATION_REQUIRED = True
        resp = client_for(customer).post("/api/v1/requests/", request_payload(category), format="json")
        assert resp.status_code == 403
        assert error(resp)["code"] == "phone_not_verified"
        User.objects.filter(pk=customer.pk).update(phone_verified_at=timezone.now())
        customer.refresh_from_db()
        assert client_for(customer).post("/api/v1/requests/", request_payload(category), format="json").status_code == 201

    def test_unverified_worker_cannot_send_offers(self, make_customer, make_worker, make_request, settings):
        customer = make_customer()
        User.objects.filter(pk=customer.pk).update(phone_verified_at=timezone.now())
        customer.refresh_from_db()
        req = make_request(customer)
        worker = make_worker()
        settings.PHONE_VERIFICATION_REQUIRED = True
        payload = {"price": "1500", "estimated_arrival_minutes": 30}
        resp = client_for(worker.user).post(f"/api/v1/requests/{req.pk}/offers/", payload, format="json")
        assert resp.status_code == 403
        User.objects.filter(pk=worker.user.pk).update(phone_verified_at=timezone.now())
        worker.user.refresh_from_db()
        assert client_for(worker.user).post(f"/api/v1/requests/{req.pk}/offers/", payload, format="json").status_code == 201

    def test_not_required_by_default_without_sms(self, customer, category):
        assert client_for(customer).post("/api/v1/requests/", request_payload(category), format="json").status_code == 201

    def test_app_config_tells_the_app(self, api, settings):
        settings.PHONE_VERIFICATION_REQUIRED = True
        settings.SMS_BACKEND = "twilio"
        settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM = "AC1", "tok", "+15005550006"
        cfg = data(api.get("/api/v1/app/config/"))["phone_verification"]
        assert cfg == {"required": True, "sms_available": True}


class TestResetBySms:
    def test_reset_with_sms_code_signs_out_everywhere(self, api, customer, outbox):
        old = client_for(customer)  # an existing session
        login = data(api.post(LOGIN, {"phone": customer.phone, "password": PASSWORD}))
        resp = api.post(RESET, {"phone": "0" + customer.phone[3:]})
        assert resp.status_code == 200
        assert data(resp)["sms_code"] is True
        code = code_in(outbox[0][1])

        resp = api.post(RESET_SMS, {"phone": customer.phone, "code": code, "new_password": "brand-new-pass-77"})
        assert resp.status_code == 200
        customer.refresh_from_db()
        assert customer.check_password("brand-new-pass-77")
        assert customer.phone_verified_at is not None  # they received the SMS
        # Old refresh tokens no longer work.
        assert api.post("/api/v1/auth/token/refresh/", {"refresh": login["tokens"]["refresh"]}).status_code == 401
        assert old is not None
        # The code is single use.
        again = api.post(RESET_SMS, {"phone": customer.phone, "code": code, "new_password": "another-pass-88"})
        assert again.status_code == 400

    def test_same_answer_for_unknown_numbers(self, api, customer, outbox):
        known = api.post(RESET, {"phone": customer.phone})
        unknown = api.post(RESET, {"phone": "03219998887"})
        assert data(known) == data(unknown)
        assert len(outbox) == 1
        # Asking again too soon is silent too.
        assert data(api.post(RESET, {"phone": customer.phone})) == data(unknown)

    def test_wrong_code_and_unknown_number_fail_the_same_way(self, api, customer, outbox):
        api.post(RESET, {"phone": customer.phone})
        code = code_in(outbox[0][1])
        wrong = "000000" if code != "000000" else "111111"
        a = api.post(RESET_SMS, {"phone": customer.phone, "code": wrong, "new_password": "brand-new-pass-77"})
        b = api.post(RESET_SMS, {"phone": "03219998887", "code": wrong, "new_password": "brand-new-pass-77"})
        assert a.status_code == b.status_code == 400
        assert error(a)["message"] == error(b)["message"]

    def test_weak_new_password_is_refused_after_a_good_code(self, api, customer, outbox):
        api.post(RESET, {"phone": customer.phone})
        resp = api.post(RESET_SMS, {"phone": customer.phone, "code": code_in(outbox[0][1]), "new_password": "12345678"})
        assert resp.status_code == 400
        customer.refresh_from_db()
        assert customer.check_password(PASSWORD)

    def test_a_verify_code_cannot_reset_a_password(self, api, customer, outbox):
        client_for(customer).post(SEND)
        resp = api.post(RESET_SMS, {"phone": customer.phone, "code": code_in(outbox[0][1]), "new_password": "brand-new-pass-77"})
        assert resp.status_code == 400


class FakeResponse:
    def __init__(self, status_code, text="{}"):
        self.status_code, self.text = status_code, text


@pytest.fixture
def twilio(settings, monkeypatch):
    settings.SMS_BACKEND = "twilio"
    settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM = "AC123", "secret", "KaamNow"
    calls = []
    state = {"status": 201}

    def post(url, data=None, auth=None, timeout=None):
        calls.append({"url": url, "data": data, "auth": auth, "timeout": timeout})
        return FakeResponse(state["status"])

    monkeypatch.setattr(requests, "post", post)
    return calls, state


class TestTwilio:
    def test_sends_through_twilio(self, twilio):
        calls, _ = twilio
        sms.send("+923001234567", "Your KaamNow code is 123456.")
        assert calls[0]["url"] == "https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json"
        assert calls[0]["data"] == {"To": "+923001234567", "From": "KaamNow", "Body": "Your KaamNow code is 123456."}
        assert calls[0]["auth"] == ("AC123", "secret") and calls[0]["timeout"]

    def test_rejection_raises(self, twilio):
        _, state = twilio
        state["status"] = 400
        with pytest.raises(sms.SmsError):
            sms.send("+923001234567", "x")

    def test_not_configured(self, settings):
        settings.SMS_BACKEND = "twilio"
        settings.TWILIO_ACCOUNT_SID = ""
        assert not sms.is_configured()
        with pytest.raises(sms.SmsError):
            sms.send("+923001234567", "x")


def test_old_codes_are_purged(customer):
    PhoneCode.objects.create(phone=customer.phone, purpose="verify", code_hash="x",
                             expires_at=timezone.now(), created_at=timezone.now() - timedelta(days=3))
    PhoneCode.objects.create(phone=customer.phone, purpose="verify", code_hash="y", expires_at=timezone.now())
    assert purge_old_phone_codes() == 1
    assert PhoneCode.objects.count() == 1
