import pytest

from apps.dashboard.models import AuditLog
from apps.notifications.models import Notification
from conftest import client_for, data

pytestmark = pytest.mark.django_db
URL = "/api/v1/complaints/"
ADMIN = "/api/v1/admin/complaints/"

PAYLOAD = {"category": "overcharging", "subject": "Charged extra cash",
           "description": "The worker asked for Rs. 500 more than the agreed price at the end of the job."}


class TestComplaints:
    def test_customer_reports_booking_problem(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = client_for(customer).post(URL, {**PAYLOAD, "booking": booking.pk})
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["status"] == "open"
        from apps.support.models import Complaint

        assert Complaint.objects.get(pk=body["id"]).against_user == worker.user
        assert Notification.objects.filter(user=customer, type="complaint").exists()

    def test_worker_can_report_customer(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = client_for(worker.user).post(URL, {**PAYLOAD, "category": "behaviour", "booking": booking.pk})
        assert resp.status_code == 201

    def test_general_complaint_without_booking(self, customer):
        assert client_for(customer).post(URL, {**PAYLOAD, "category": "app_issue"}).status_code == 201

    def test_cannot_report_others_booking(self, customer, worker, make_booking, make_customer):
        booking = make_booking(customer, worker)
        assert client_for(make_customer()).post(URL, {**PAYLOAD, "booking": booking.pk}).status_code == 403

    def test_one_open_complaint_per_booking(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        c = client_for(customer)
        assert c.post(URL, {**PAYLOAD, "booking": booking.pk}).status_code == 201
        assert c.post(URL, {**PAYLOAD, "booking": booking.pk}).status_code == 409

    def test_validation(self, customer):
        assert client_for(customer).post(URL, {**PAYLOAD, "description": "too short"}).status_code == 400
        assert client_for(customer).post(URL, {**PAYLOAD, "category": "bogus"}).status_code == 400

    def test_users_see_only_their_own(self, customer, make_customer):
        client_for(customer).post(URL, PAYLOAD)
        other = make_customer()
        assert data(client_for(other).get(URL))["count"] == 0
        cid = data(client_for(customer).get(URL))["results"][0]["id"]
        assert client_for(other).get(f"{URL}{cid}/").status_code == 404


class TestAdminComplaints:
    def test_review_and_resolve(self, admin_user, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        cid = data(client_for(customer).post(URL, {**PAYLOAD, "booking": booking.pk}))["id"]
        admin = client_for(admin_user)
        listing = data(admin.get(ADMIN, {"status": "open"}))["results"]
        assert listing[0]["against_user"] == worker.user.pk
        assert admin.post(f"{ADMIN}{cid}/status/", {"status": "in_review"}).status_code == 200
        assert admin.post(f"{ADMIN}{cid}/status/", {"status": "resolved"}).status_code == 400  # needs resolution
        resp = admin.post(f"{ADMIN}{cid}/status/", {"status": "resolved", "resolution": "Refunded Rs. 500."})
        assert data(resp)["status"] == "resolved" and data(resp)["resolved_by"] == admin_user.pk
        assert admin.post(f"{ADMIN}{cid}/status/", {"status": "in_review"}).status_code == 409
        assert AuditLog.objects.filter(action="complaint_updated").count() == 2
        assert Notification.objects.filter(user=customer, type="complaint", title__contains="resolved").exists()

    def test_non_admin_forbidden(self, customer, worker):
        for user in (customer, worker.user):
            assert client_for(user).get(ADMIN).status_code == 403
