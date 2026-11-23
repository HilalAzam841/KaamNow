import re

import pytest
from django.core import mail

from apps.accounts.models import User, WorkerProfile
from conftest import PASSWORD, client_for, data

pytestmark = pytest.mark.django_db

REGISTER = "/api/v1/auth/register/"
LOGIN = "/api/v1/auth/login/"


class TestRegistration:
    def test_customer_registration_returns_tokens(self, api):
        resp = api.post(REGISTER, {"phone": "0300-1112223", "password": PASSWORD, "full_name": "Sara Ali"})
        assert resp.status_code == 201
        body = data(resp)
        assert body["user"]["phone"] == "+923001112223"
        assert body["user"]["role"] == "customer"
        assert body["tokens"]["access"] and body["tokens"]["refresh"]
        user = User.objects.get(phone="+923001112223")
        assert user.check_password(PASSWORD)
        assert not user.password.startswith(PASSWORD)  # hashed

    def test_worker_registration_creates_pending_profile(self, api):
        resp = api.post(REGISTER, {
            "phone": "03001112224", "password": PASSWORD, "full_name": "Usman Tariq", "role": "worker",
            "cnic_number": "35202-7654321-9",
        })
        assert resp.status_code == 201
        profile = WorkerProfile.objects.get(user__phone="+923001112224")
        assert profile.verification_status == "pending"
        assert profile.cnic_number == "3520276543219"
        assert data(resp)["user"]["worker_profile_id"] == profile.pk

    def test_worker_requires_cnic(self, api):
        resp = api.post(REGISTER, {"phone": "03001112225", "password": PASSWORD, "full_name": "X Y", "role": "worker"})
        assert resp.status_code == 400
        assert resp.json()["success"] is False
        assert "cnic_number" in resp.json()["error"]["details"]

    def test_cannot_self_register_as_admin(self, api):
        resp = api.post(REGISTER, {"phone": "03001112226", "password": PASSWORD, "full_name": "Hacker", "role": "admin"})
        assert resp.status_code == 400

    def test_duplicate_phone_rejected(self, api, customer):
        resp = api.post(REGISTER, {"phone": customer.phone, "password": PASSWORD, "full_name": "Dup User"})
        assert resp.status_code == 400
        assert "phone" in resp.json()["error"]["details"]

    @pytest.mark.parametrize("password", ["short", "12345678901", "password123"])
    def test_weak_password_rejected(self, api, password):
        resp = api.post(REGISTER, {"phone": "03001112227", "password": password, "full_name": "Weak Pass"})
        assert resp.status_code == 400

    def test_invalid_phone_rejected(self, api):
        resp = api.post(REGISTER, {"phone": "12345", "password": PASSWORD, "full_name": "Bad Phone"})
        assert resp.status_code == 400


class TestLogin:
    def test_login_success(self, api, customer):
        resp = api.post(LOGIN, {"phone": customer.phone.replace("+92", "0"), "password": PASSWORD})
        assert resp.status_code == 200
        assert data(resp)["user"]["id"] == customer.pk

    def test_login_wrong_password(self, api, customer):
        resp = api.post(LOGIN, {"phone": customer.phone, "password": "wrong-password"})
        assert resp.status_code == 400
        assert resp.json()["error"]["message"] == "Invalid phone number or password."

    def test_login_unknown_user_same_message(self, api):
        resp = api.post(LOGIN, {"phone": "03009999999", "password": "whatever-123"})
        assert resp.status_code == 400
        assert resp.json()["error"]["message"] == "Invalid phone number or password."

    def test_suspended_user_cannot_login(self, api, customer):
        customer.is_suspended = True
        customer.save()
        resp = api.post(LOGIN, {"phone": customer.phone, "password": PASSWORD})
        assert resp.status_code == 400
        assert "suspended" in resp.json()["error"]["message"]

    def test_token_authenticates_requests(self, api, customer):
        tokens = data(api.post(LOGIN, {"phone": customer.phone, "password": PASSWORD}))["tokens"]
        api.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        assert data(api.get("/api/v1/auth/me/"))["phone"] == customer.phone

    def test_suspended_user_token_rejected(self, api, customer):
        tokens = data(api.post(LOGIN, {"phone": customer.phone, "password": PASSWORD}))["tokens"]
        customer.is_suspended = True
        customer.save()
        api.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        assert api.get("/api/v1/auth/me/").status_code == 401

    def test_unauthenticated_me(self, api):
        resp = api.get("/api/v1/auth/me/")
        assert resp.status_code == 401
        assert resp.json()["success"] is False


class TestTokens:
    def test_refresh_and_logout_blacklists(self, api, customer):
        tokens = data(api.post(LOGIN, {"phone": customer.phone, "password": PASSWORD}))["tokens"]
        resp = api.post("/api/v1/auth/token/refresh/", {"refresh": tokens["refresh"]})
        assert resp.status_code == 200
        new = data(resp)
        assert new["access"]
        # Rotation blacklists the old refresh token.
        assert api.post("/api/v1/auth/token/refresh/", {"refresh": tokens["refresh"]}).status_code == 401

        api.credentials(HTTP_AUTHORIZATION=f"Bearer {new['access']}")
        assert api.post("/api/v1/auth/logout/", {"refresh": new["refresh"]}).status_code == 200
        assert api.post("/api/v1/auth/token/refresh/", {"refresh": new["refresh"]}).status_code == 401

    def test_logout_with_someone_elses_token_rejected(self, api, customer, make_customer):
        other = make_customer()
        tokens = data(api.post(LOGIN, {"phone": other.phone, "password": PASSWORD}))["tokens"]
        resp = client_for(customer).post("/api/v1/auth/logout/", {"refresh": tokens["refresh"]})
        assert resp.status_code == 400

    def test_logout_invalid_token(self, customer):
        assert client_for(customer).post("/api/v1/auth/logout/", {"refresh": "garbage"}).status_code == 400


class TestProfile:
    def test_update_profile(self, customer):
        client = client_for(customer)
        resp = client.patch("/api/v1/auth/me/", {"full_name": "Ayesha K.", "email": "Ayesha@Example.com"})
        assert resp.status_code == 200
        assert data(resp)["email"] == "ayesha@example.com"

    def test_cannot_change_role_or_phone(self, customer):
        client = client_for(customer)
        client.patch("/api/v1/auth/me/", {"role": "admin", "phone": "+923331234567"})
        customer.refresh_from_db()
        assert customer.role == "customer"
        assert customer.phone != "+923331234567"

    def test_change_password(self, customer):
        client = client_for(customer)
        resp = client.post("/api/v1/auth/password-change/", {"current_password": "nope", "new_password": "N3w-Passw0rd!"})
        assert resp.status_code == 400
        resp = client.post("/api/v1/auth/password-change/", {"current_password": PASSWORD, "new_password": "N3w-Passw0rd!"})
        assert resp.status_code == 200
        customer.refresh_from_db()
        assert customer.check_password("N3w-Passw0rd!")


class TestPasswordReset:
    def test_full_reset_flow(self, api, make_customer):
        user = make_customer(email="reset@example.com")
        resp = api.post("/api/v1/auth/password-reset/", {"email": "reset@example.com"})
        assert resp.status_code == 200
        assert len(mail.outbox) == 1
        match = re.search(r"uid=([^&\s]+)&token=([^\s]+)", mail.outbox[0].body)
        uid, token = match.groups()
        resp = api.post("/api/v1/auth/password-reset/confirm/", {"uid": uid, "token": token, "new_password": "Brand-N3w-Pass"})
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.check_password("Brand-N3w-Pass")
        # Token is single-use (password hash changed).
        resp = api.post("/api/v1/auth/password-reset/confirm/", {"uid": uid, "token": token, "new_password": "Another-P4ss"})
        assert resp.status_code == 400

    def test_unknown_account_same_response(self, api):
        resp = api.post("/api/v1/auth/password-reset/", {"phone": "03007777777"})
        assert resp.status_code == 200
        assert len(mail.outbox) == 0

    def test_bad_token(self, api, customer):
        resp = api.post("/api/v1/auth/password-reset/confirm/", {"uid": "MQ", "token": "bad", "new_password": "Brand-N3w-Pass"})
        assert resp.status_code == 400


class TestThrottling:
    def test_login_is_throttled(self, api, monkeypatch, customer):
        from rest_framework.throttling import SimpleRateThrottle

        monkeypatch.setitem(SimpleRateThrottle.THROTTLE_RATES, "auth", "3/min")
        codes = [api.post(LOGIN, {"phone": customer.phone, "password": "bad-pass"}).status_code for _ in range(4)]
        assert codes == [400, 400, 400, 429]
        assert api.post(LOGIN, {"phone": customer.phone, "password": PASSWORD}).json()["success"] is False
