from decimal import Decimal

import pytest

from apps.billing.models import LedgerEntry, PlatformSettings
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from conftest import advance_to, client_for, data, request_payload

pytestmark = pytest.mark.django_db


class TestEmergency:
    def test_fee_locked_and_added_to_total(self, customer, worker, category, make_offer,
                                           django_capture_on_commit_callbacks):
        with django_capture_on_commit_callbacks(execute=True):
            resp = client_for(customer).post("/api/v1/requests/", request_payload(category, is_emergency=True))
        req = data(resp)
        assert req["is_emergency"] is True and req["emergency_fee"] == "300.00"
        assert Notification.objects.get(user=worker.user, type="new_request").title.startswith("URGENT")

        # Admin raises the fee later: existing request keeps the locked fee.
        settings_obj = PlatformSettings.load()
        settings_obj.emergency_fee = Decimal("500")
        settings_obj.save()

        from apps.jobs.models import ServiceRequest
        from apps.offers.services import accept_offer

        offer = make_offer(worker, ServiceRequest.objects.get(pk=req["id"]), "1000")
        booking = accept_offer(offer, customer)
        assert booking.emergency_fee == Decimal("300.00")
        body = data(client_for(customer).get(f"/api/v1/bookings/{booking.pk}/"))
        assert (body["agreed_price"], body["emergency_fee"], body["total_amount"]) == ("1000.00", "300.00", "1300.00")

        booking = advance_to(booking, Booking.Status.IN_PROGRESS)
        client_for(customer).post(f"/api/v1/bookings/{booking.pk}/complete/", {"confirm": True})
        payment = data(client_for(customer).post("/api/v1/payments/", {"booking": booking.pk}))
        assert payment["amount"] == "1300.00"
        client_for(worker.user).post(f"/api/v1/payments/{payment['id']}/confirm/")
        entries = {e.entry_type: e.amount for e in LedgerEntry.objects.filter(payment_id=payment["id"])}
        # Commission is on the negotiated price only; the fee is separate platform revenue.
        assert entries == {"customer_payment": Decimal("1300.00"), "platform_commission": Decimal("100.00"),
                           "worker_earning": Decimal("900.00"), "emergency_fee": Decimal("300.00")}

    def test_normal_request_has_no_fee(self, customer, category):
        req = data(client_for(customer).post("/api/v1/requests/", request_payload(category)))
        assert req["is_emergency"] is False and req["emergency_fee"] == "0.00"

    def test_disabled(self, customer, category):
        s = PlatformSettings.load()
        s.emergency_enabled = False
        s.save()
        resp = client_for(customer).post("/api/v1/requests/", request_payload(category, is_emergency=True))
        assert resp.status_code == 400

    def test_worker_feed_shows_emergencies_first(self, customer, worker, category):
        c = client_for(customer)
        normal = data(c.post("/api/v1/requests/", request_payload(category)))
        urgent = data(c.post("/api/v1/requests/", request_payload(category, is_emergency=True)))
        newer = data(c.post("/api/v1/requests/", request_payload(category)))
        feed = data(client_for(worker.user).get("/api/v1/requests/"))["results"]
        assert [r["id"] for r in feed] == [urgent["id"], newer["id"], normal["id"]]

    def test_admin_configures_fee(self, admin_user, customer):
        client = client_for(admin_user)
        resp = client.patch("/api/v1/admin/settings/", {"emergency_fee": "450.00"})
        assert data(resp)["emergency_fee"] == "450.00"
        assert client.patch("/api/v1/admin/settings/", {"emergency_fee": "-1"}).status_code == 400
        assert client_for(customer).patch("/api/v1/admin/settings/", {"emergency_fee": "1"}).status_code == 403
        from apps.dashboard.models import AuditLog

        log = AuditLog.objects.get(action="settings_changed")
        assert log.metadata["changes"]["emergency_fee"] == {"old": "300.00", "new": "450.00"}
