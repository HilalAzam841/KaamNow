from datetime import timedelta
from unittest import mock

import pytest
from django.utils import timezone

from apps.common.sms import SmsError
from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.safety.models import EmergencyContact, SosAlert, TripShare
from conftest import advance_to, client_for, data

CONTACTS = "/api/v1/safety/contacts/"


def sos(user, booking, **body):
    return client_for(user).post(f"/api/v1/bookings/{booking.pk}/sos/", body, format="json")


def share(user, booking, **body):
    return client_for(user).post(f"/api/v1/bookings/{booking.pk}/share/", body, format="json")


def token_of(url):
    return url.rsplit("/", 1)[1]


@pytest.fixture(autouse=True)
def sms_on(monkeypatch):
    monkeypatch.setattr("apps.common.sms.is_available", lambda: True)


@pytest.fixture
def booking(customer, worker, make_booking):
    return make_booking(customer, worker)


@pytest.mark.django_db
class TestContacts:
    def test_add_list_remove(self, customer, make_customer):
        c = client_for(customer)
        resp = c.post(CONTACTS, {"name": "Ammi", "phone": "0300 1112223"}, format="json")
        assert resp.status_code == 201 and data(resp)["phone"] == "+923001112223"
        assert c.post(CONTACTS, {"name": "Again", "phone": "+923001112223"}, format="json").status_code == 409
        assert c.post(CONTACTS, {"name": "Me", "phone": customer.phone}, format="json").status_code == 400
        assert c.post(CONTACTS, {"name": "Bad", "phone": "12345"}, format="json").status_code == 400
        for i in range(2):
            assert c.post(CONTACTS, {"name": f"C{i}", "phone": f"+92300111222{i + 4}"}, format="json").status_code == 201
        assert c.post(CONTACTS, {"name": "Fourth", "phone": "+923001112229"}, format="json").status_code == 400
        rows = data(c.get(CONTACTS))
        assert len(rows) == 3
        # Others cannot see or delete them.
        stranger = client_for(make_customer())
        assert data(stranger.get(CONTACTS)) == []
        assert stranger.delete(f"{CONTACTS}{rows[0]['id']}/").status_code == 404
        assert c.delete(f"{CONTACTS}{rows[0]['id']}/").status_code == 204
        assert EmergencyContact.objects.filter(user=customer).count() == 2

    def test_needs_login(self, api):
        assert api.get(CONTACTS).status_code == 401


@pytest.mark.django_db
class TestSos:
    def test_customer_sos_alerts_admins_and_texts_contacts(self, customer, booking, admin_user,
                                                            django_capture_on_commit_callbacks):
        EmergencyContact.objects.create(user=customer, name="Ammi", phone="+923001112223")
        with mock.patch("apps.common.sms.send") as send, django_capture_on_commit_callbacks(execute=True):
            resp = sos(customer, booking, note="He is shouting", latitude="31.510000", longitude="74.344000")
        assert resp.status_code == 201
        body = data(resp)
        assert body["status"] == "open" and body["contacts_texted"] == 1
        phone, text = send.call_args.args
        assert phone == "+923001112223" and customer.phone in text and "/share/" in text
        note = Notification.objects.get(user=admin_user, type=Notification.Type.SAFETY)
        assert note.data["booking_id"] == booking.pk
        # The worker is not told.
        assert not Notification.objects.filter(user=booking.worker.user, type=Notification.Type.SAFETY).exists()
        # The SMS link works for the family.
        from rest_framework.test import APIClient

        assert APIClient().get(f"/api/v1/safety/shared/{token_of(text.split()[-1])}/").status_code == 200
        # Pressing again returns the same alert.
        again = sos(customer, booking)
        assert again.status_code == 200 and data(again)["id"] == body["id"]
        assert SosAlert.objects.count() == 1
        # The booking shows the open alert to the customer only.
        b = data(client_for(customer).get(f"/api/v1/bookings/{booking.pk}/"))
        assert b["safety"]["sos_status"] == "open" and b["safety"]["can_sos"] is True
        w = data(client_for(booking.worker.user).get(f"/api/v1/bookings/{booking.pk}/"))
        assert w["safety"]["sos_status"] is None

    def test_worker_sos_uses_last_location_and_sms_failure_is_ok(self, worker, booking):
        from apps.tracking.services import record_location

        booking = advance_to(booking, Booking.Status.ON_THE_WAY)
        record_location(booking, worker.user, latitude="31.500000", longitude="74.300000")
        EmergencyContact.objects.create(user=worker.user, name="Bhai", phone="+923001112223")
        with mock.patch("apps.common.sms.send", side_effect=SmsError("down")):
            resp = sos(worker.user, booking)
        assert resp.status_code == 201 and data(resp)["contacts_texted"] == 0
        alert = SosAlert.objects.get()
        assert alert.role == "worker" and str(alert.latitude) == "31.500000"

    def test_only_participants_and_only_during_the_job(self, booking, customer, make_customer):
        assert sos(make_customer(), booking).status_code == 404
        from apps.jobs.services import cancel_booking

        cancel_booking(booking, customer, "Changed plans")
        resp = sos(customer, booking)
        assert resp.status_code == 409 and "15" in resp.json()["error"]["message"]

    def test_allowed_for_an_hour_after_completion(self, customer, worker, completed_booking_factory):
        b = completed_booking_factory(customer, worker)
        assert sos(customer, b).status_code == 201
        Booking.objects.filter(pk=b.pk).update(completed_at=timezone.now() - timedelta(hours=2))
        assert sos(worker.user, b).status_code == 409

    def test_half_a_location_is_refused(self, customer, booking):
        assert sos(customer, booking, latitude="31.5").status_code == 400

    def test_admin_handles_with_audit(self, customer, booking, admin_user, worker):
        sos(customer, booking)
        alert = SosAlert.objects.get()
        a = client_for(admin_user)
        rows = data(a.get("/api/v1/admin/sos-alerts/?status=open"))["results"]
        assert rows[0]["raised_by_phone"] == customer.phone
        assert rows[0]["other_party"] == {"name": worker.user.full_name, "phone": worker.user.phone, "role": "worker"}
        assert rows[0]["address"] == booking.request.address
        resp = a.post(f"/api/v1/admin/sos-alerts/{alert.pk}/handle/", {"status": "acknowledged", "note": "Called"},
                      format="json")
        assert data(resp)["status"] == "acknowledged" and data(resp)["handled_by_name"] == admin_user.full_name
        assert Notification.objects.filter(user=customer, type=Notification.Type.SAFETY).exists()
        a.post(f"/api/v1/admin/sos-alerts/{alert.pk}/handle/", {"status": "resolved"}, format="json")
        assert a.post(f"/api/v1/admin/sos-alerts/{alert.pk}/handle/", {"status": "resolved"},
                      format="json").status_code == 409
        assert AuditLog.objects.filter(action=AuditLog.Action.SOS_HANDLED).count() == 2
        # After it is resolved, a new SOS makes a new alert.
        assert sos(customer, booking).status_code == 201
        # Not for non-admins.
        assert client_for(customer).get("/api/v1/admin/sos-alerts/").status_code == 403


@pytest.mark.django_db
class TestSharing:
    def test_share_follow_and_turn_off(self, customer, worker, booking, api):
        resp = share(customer, booking)
        assert resp.status_code == 201
        url = data(resp)["url"]
        assert url.startswith("https://app.kaamnow.pk/share/")
        # Only a hash is stored.
        assert token_of(url) not in TripShare.objects.get().token_hash
        public = api.get(f"/api/v1/safety/shared/{token_of(url)}/")
        body = data(public)
        assert body["status"] == "confirmed" and body["shared_by"] == "customer"
        assert body["worker"]["name"] == worker.user.full_name.split(" ")[0]
        text = public.content.decode()
        for secret in (customer.phone, worker.user.phone, booking.request.address, str(booking.request.latitude)):
            assert secret not in text
        assert body["worker_location"] is None
        assert data(client_for(customer).get(f"/api/v1/bookings/{booking.pk}/"))["safety"]["sharing_until"]
        # Worker on the way: family sees the worker's position, then not after arrival.
        from apps.tracking.services import record_location

        booking = advance_to(booking, Booking.Status.ON_THE_WAY)
        record_location(booking, worker.user, latitude="31.500000", longitude="74.300000")
        assert data(api.get(f"/api/v1/safety/shared/{token_of(url)}/"))["worker_location"]["latitude"] == "31.500000"
        from apps.jobs.services import update_booking_status

        booking = update_booking_status(booking, worker.user, Booking.Status.ARRIVED)
        assert data(api.get(f"/api/v1/safety/shared/{token_of(url)}/"))["worker_location"] is None
        # Sharing again replaces the link.
        url2 = data(share(customer, booking))["url"]
        assert api.get(f"/api/v1/safety/shared/{token_of(url)}/").status_code == 404
        assert client_for(customer).delete(f"/api/v1/bookings/{booking.pk}/share/").status_code == 204
        assert api.get(f"/api/v1/safety/shared/{token_of(url2)}/").status_code == 404

    def test_expired_and_wrong_links(self, customer, booking, api):
        url = data(share(customer, booking))["url"]
        TripShare.objects.update(expires_at=timezone.now() - timedelta(minutes=1))
        assert api.get(f"/api/v1/safety/shared/{token_of(url)}/").status_code == 404
        assert api.get("/api/v1/safety/shared/not-a-real-token/").status_code == 404

    def test_send_to_contacts(self, customer, booking):
        assert share(customer, booking, send_to_contacts=True).status_code == 400  # no contacts yet
        EmergencyContact.objects.create(user=customer, name="Ammi", phone="+923001112223")
        with mock.patch("apps.common.sms.send") as send:
            resp = share(customer, booking, send_to_contacts=True)
        assert data(resp)["contacts_texted"] == 1 and data(resp)["url"] in send.call_args.args[1]

    def test_only_participants_and_active_jobs(self, customer, worker, booking, make_customer,
                                               completed_booking_factory):
        assert share(make_customer(), booking).status_code == 404
        assert share(worker.user, booking).status_code == 201
        done = completed_booking_factory(customer, worker)
        assert share(customer, done).status_code == 409

    def test_sms_in_the_users_language(self, customer, booking):
        customer.language = "ur"
        customer.save()
        EmergencyContact.objects.create(user=customer, name="Ammi", phone="+923001112223")
        with mock.patch("apps.common.sms.send") as send:
            share(customer, booking, send_to_contacts=True)
        assert "کام ناؤ" in send.call_args.args[1]


@pytest.mark.django_db
def test_no_sms_service_still_raises_the_alert(customer, booking, monkeypatch):
    monkeypatch.setattr("apps.common.sms.is_available", lambda: False)
    EmergencyContact.objects.create(user=customer, name="Ammi", phone="+923001112223")
    with mock.patch("apps.common.sms.send") as send:
        resp = sos(customer, booking)
    assert resp.status_code == 201 and data(resp)["contacts_texted"] == 0
    send.assert_not_called()
