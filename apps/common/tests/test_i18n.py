"""Urdu support: the request language, the user's saved language, alerts and category names."""

import gettext
import re
from pathlib import Path

import pytest
from django.conf import settings
from django.utils import translation

from apps.notifications.models import Notification
from conftest import PASSWORD, client_for

LOCALE = Path(settings.BASE_DIR) / "locale" / "ur" / "LC_MESSAGES"
ME = "/api/v1/auth/me/"


def error_message(resp):
    return resp.json()["error"]["message"]


@pytest.mark.django_db
class TestRequestLanguage:
    def test_errors_follow_accept_language(self, api, customer):
        body = {"phone": customer.phone, "password": "wrong-password"}
        english = api.post("/api/v1/auth/login/", body, format="json")
        urdu = api.post("/api/v1/auth/login/", body, format="json", HTTP_ACCEPT_LANGUAGE="ur")
        assert english.status_code == urdu.status_code == 400
        assert error_message(english) == "Invalid phone number or password."
        assert error_message(urdu) == "فون نمبر یا پاس ورڈ غلط ہے۔"
        assert urdu["Content-Language"] == "ur"

    def test_unsupported_language_falls_back_to_english(self, api, customer):
        resp = api.post("/api/v1/auth/login/", {"phone": customer.phone, "password": "x"}, format="json",
                        HTTP_ACCEPT_LANGUAGE="fr")
        assert error_message(resp) == "Invalid phone number or password."

    def test_permission_messages_are_translated(self, customer):
        resp = client_for(customer).get("/api/v1/workers/me/", HTTP_ACCEPT_LANGUAGE="ur")
        assert resp.status_code == 403
        assert error_message(resp) == "یہ کام صرف کاریگر کر سکتے ہیں۔"

    def test_login_still_works_in_urdu(self, api, customer):
        resp = api.post("/api/v1/auth/login/", {"phone": customer.phone, "password": PASSWORD}, format="json",
                        HTTP_ACCEPT_LANGUAGE="ur")
        assert resp.status_code == 200


@pytest.mark.django_db
class TestSavedLanguage:
    def test_me_returns_and_updates_language(self, customer):
        c = client_for(customer)
        assert c.get(ME).json()["data"]["language"] == "en"
        resp = c.patch(ME, {"language": "ur"}, format="json")
        assert resp.status_code == 200 and resp.json()["data"]["language"] == "ur"
        customer.refresh_from_db()
        assert customer.language == "ur"

    def test_only_english_and_urdu_are_accepted(self, customer):
        resp = client_for(customer).patch(ME, {"language": "fr"}, format="json")
        assert resp.status_code == 400
        customer.refresh_from_db()
        assert customer.language == "en"


@pytest.mark.django_db
class TestAlerts:
    def test_alerts_use_the_recipients_language_not_the_senders(self, make_customer, make_worker, make_request,
                                                                 make_offer):
        urdu_customer = make_customer(language="ur")
        worker = make_worker()  # English
        req = make_request(urdu_customer)
        with translation.override("en"):  # the worker's own request is in English
            make_offer(worker, req, "1500")
        alert = Notification.objects.get(user=urdu_customer, type=Notification.Type.NEW_OFFER)
        assert alert.title == "نئی پیشکش موصول ہوئی"
        assert "1,500 روپے" in alert.body and "Bilal Ahmed" in alert.body

    def test_english_recipient_gets_english_during_an_urdu_request(self, make_customer, make_worker, make_booking):
        customer = make_customer(language="ur")
        worker = make_worker()
        with translation.override("ur"):
            booking = make_booking(customer, worker, "1200")
        alert = Notification.objects.get(user=worker.user, type=Notification.Type.OFFER_ACCEPTED)
        assert alert.title == "Offer accepted"
        assert alert.body == f"Your offer of Rs. 1,200 was accepted. Booking #{booking.pk} is confirmed."

    def test_booking_status_alert_in_urdu(self, make_customer, make_worker, make_booking):
        from conftest import advance_to

        customer = make_customer(language="ur")
        booking = make_booking(customer, make_worker())
        advance_to(booking, "on_the_way")
        alert = Notification.objects.filter(user=customer, type=Notification.Type.BOOKING_STATUS).latest("id")
        assert alert.body == "آپ کا کاریگر راستے میں ہے۔"


@pytest.mark.django_db
class TestCategoryNames:
    def test_category_names_in_urdu_when_asked(self, api, category):
        category.name_ur = "الیکٹریشن"
        category.save()
        english = api.get("/api/v1/services/categories/").json()["data"]
        urdu = api.get("/api/v1/services/categories/", HTTP_ACCEPT_LANGUAGE="ur").json()["data"]
        by_id = lambda rows: {r["id"]: r for r in (rows["results"] if isinstance(rows, dict) else rows)}  # noqa: E731
        assert by_id(english)[category.pk]["name"] == "Electrician"
        assert by_id(urdu)[category.pk]["name"] == "الیکٹریشن"
        assert by_id(urdu)[category.pk]["name_ur"] == "الیکٹریشن"

    def test_falls_back_to_english_without_an_urdu_name(self, api):
        from apps.catalog.models import ServiceCategory

        other_category = ServiceCategory.objects.create(name="Gardener")
        rows = api.get("/api/v1/services/categories/", HTTP_ACCEPT_LANGUAGE="ur").json()["data"]
        rows = rows["results"] if isinstance(rows, dict) else rows
        assert next(r for r in rows if r["id"] == other_category.pk)["name"] == "Gardener"

    def test_request_category_name_follows_language(self, make_customer, make_request, category):
        category.name_ur = "الیکٹریشن"
        category.save()
        customer = make_customer()
        req = make_request(customer)
        resp = client_for(customer).get(f"/api/v1/requests/{req.pk}/", HTTP_ACCEPT_LANGUAGE="ur")
        assert resp.json()["data"]["category_name"] == "الیکٹریشن"

    def test_admin_can_set_the_urdu_name(self, admin_user):
        resp = client_for(admin_user).post("/api/v1/services/categories/",
                                           {"name": "Gardener", "name_ur": "مالی"}, format="json")
        assert resp.status_code == 201, resp.json()
        assert resp.json()["data"]["name"] == "Gardener" and resp.json()["data"]["name_ur"] == "مالی"


class TestCatalog:
    """The compiled catalog matches the .po file and keeps every {placeholder}."""

    def test_mo_file_is_compiled_from_the_po_file(self):
        polib = pytest.importorskip("polib")
        po = polib.pofile(str(LOCALE / "django.po"))
        with open(LOCALE / "django.mo", "rb") as fh:
            mo = gettext.GNUTranslations(fh)
        for entry in po:
            if entry.msgid_plural:
                assert mo.ngettext(entry.msgid, entry.msgid_plural, 1) == entry.msgstr_plural[0]
            else:
                assert mo.gettext(entry.msgid) == entry.msgstr, (
                    f"django.mo is out of date for {entry.msgid!r}: run python scripts/compile_messages.py"
                )

    def test_every_message_is_translated_with_the_same_placeholders(self):
        polib = pytest.importorskip("polib")
        names = lambda s: sorted(re.findall(r"\{(\w+)\}", s))  # noqa: E731
        for entry in polib.pofile(str(LOCALE / "django.po")):
            translations = entry.msgstr_plural.values() if entry.msgid_plural else [entry.msgstr]
            for text in translations:
                assert text, f"missing Urdu for {entry.msgid!r}"
                assert names(text) == names(entry.msgid), entry.msgid
