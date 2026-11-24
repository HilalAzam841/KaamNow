import pytest

from apps.billing.models import PlatformSettings

pytestmark = pytest.mark.django_db

URL = "/api/v1/app/config/"


def test_public_and_reflects_platform_settings(api):
    platform = PlatformSettings.load()
    platform.emergency_fee = "450.00"
    platform.emergency_enabled = False
    platform.save()

    resp = api.get(URL)
    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["emergency"] == {"enabled": False, "fee": "450.00"}
    assert body["currency"] == "PKR"
    assert body["city"]["name"] == "Lahore"
    assert set(body["min_supported_version"]) == {"android", "ios", "web"}
    assert "{booking_id}" in body["websocket_path"]


def test_payment_methods_reflect_gateway_configuration(api, settings):
    settings.PAYMENT_GATEWAYS = {"jazzcash": {}, "easypaisa": {}}
    methods = {m["code"]: m["available"] for m in api.get(URL).json()["data"]["payment_methods"]}
    assert methods == {"cash": True, "jazzcash": False, "easypaisa": False}


def test_gateway_marked_available_when_configured(api, gateways):
    methods = {m["code"]: m["available"] for m in api.get(URL).json()["data"]["payment_methods"]}
    assert methods["jazzcash"] is True and methods["easypaisa"] is True


def test_no_secrets_leak(api, gateways):
    text = api.get(URL).content.decode()
    for cfg in gateways.values():
        for key in ("PASSWORD", "INTEGRITY_SALT", "HASH_KEY"):
            if cfg.get(key):
                assert cfg[key] not in text


def test_cors_allows_configured_browser_origin(api, settings):
    settings.CORS_ALLOWED_ORIGINS = ["https://app.kaamnow.pk"]
    settings.CORS_ALLOWED_ORIGIN_REGEXES = []
    ok = api.options(URL, HTTP_ORIGIN="https://app.kaamnow.pk", HTTP_ACCESS_CONTROL_REQUEST_METHOD="GET")
    assert ok["Access-Control-Allow-Origin"] == "https://app.kaamnow.pk"
    bad = api.options(URL, HTTP_ORIGIN="https://evil.example", HTTP_ACCESS_CONTROL_REQUEST_METHOD="GET")
    assert "Access-Control-Allow-Origin" not in bad
