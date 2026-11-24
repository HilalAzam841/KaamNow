
import pytest

from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking
from apps.jobs.services import confirm_completion_by_customer
from conftest import PASSWORD, add_cnic_documents, advance_to, client_for, data

pytestmark = pytest.mark.django_db
A = "/api/v1/admin/"

ADMIN_GET_ENDPOINTS = ["dashboard/", "workers/pending/", "bookings/", "revenue/", "commissions/", "reports/",
                       "users/", "requests/", "audit-logs/", "settings/commission/"]


class TestAdminPermissions:
    @pytest.mark.parametrize("path", ADMIN_GET_ENDPOINTS)
    def test_non_admins_forbidden(self, path, customer, worker, api):
        assert api.get(A + path).status_code == 401
        assert client_for(customer).get(A + path).status_code == 403
        assert client_for(worker.user).get(A + path).status_code == 403

    @pytest.mark.parametrize("path", ADMIN_GET_ENDPOINTS)
    def test_admin_allowed(self, path, admin_user):
        assert client_for(admin_user).get(A + path).status_code == 200


class TestWorkerVerification:
    def test_pending_list_verify_and_audit(self, admin_user, make_worker):
        w = make_worker(verified=False, available=False)
        add_cnic_documents(w)
        client = client_for(admin_user)
        pending = data(client.get(A + "workers/pending/"))["results"]
        assert [p["id"] for p in pending] == [w.pk]
        assert len(pending[0]["documents"]) == 2
        assert "file" not in pending[0]["documents"][0]

        resp = client.post(f"{A}workers/{w.pk}/verify/")
        assert resp.status_code == 200
        w.refresh_from_db()
        assert w.verification_status == "verified"
        assert w.verified_by == admin_user
        assert set(w.documents.values_list("status", flat=True)) == {"approved"}
        log = AuditLog.objects.get(action="worker_verified")
        assert log.actor == admin_user and log.target_id == str(w.pk)
        assert client.post(f"{A}workers/{w.pk}/verify/").status_code == 400  # already verified

    def test_verify_requires_documents(self, admin_user, make_worker):
        w = make_worker(verified=False)
        resp = client_for(admin_user).post(f"{A}workers/{w.pk}/verify/")
        assert resp.status_code == 400
        assert "CNIC" in resp.json()["error"]["message"]

    def test_reject_with_reason(self, admin_user, make_worker):
        w = make_worker(verified=True, available=True)
        client = client_for(admin_user)
        assert client.post(f"{A}workers/{w.pk}/reject/", {}).status_code == 400
        resp = client.post(f"{A}workers/{w.pk}/reject/", {"reason": "CNIC photo unreadable"})
        assert resp.status_code == 200
        w.refresh_from_db()
        assert w.verification_status == "rejected" and not w.is_available
        assert AuditLog.objects.filter(action="worker_rejected", metadata__reason="CNIC photo unreadable").exists()

    def test_document_download_is_audited(self, admin_user, make_worker, customer):
        w = make_worker(verified=False)
        add_cnic_documents(w)
        doc = w.documents.first()
        resp = client_for(admin_user).get(f"{A}documents/{doc.pk}/file/")
        assert resp.status_code == 200
        assert resp["Cache-Control"] == "no-store"
        assert b"".join(resp.streaming_content)[:3] == b"\xff\xd8\xff"  # JPEG
        assert AuditLog.objects.filter(action="document_viewed", target_id=str(doc.pk)).exists()
        assert client_for(customer).get(f"{A}documents/{doc.pk}/file/").status_code == 403
        assert client_for(w.user).get(f"{A}documents/{doc.pk}/file/").status_code == 403


class TestSuspension:
    def test_suspend_blocks_access_and_reactivate(self, admin_user, worker, api):
        tokens = data(api.post("/api/v1/auth/login/", {"phone": worker.user.phone, "password": PASSWORD}))["tokens"]
        client = client_for(admin_user)
        resp = client.post(f"{A}users/{worker.user.pk}/suspend/", {"reason": "Fraudulent bids"})
        assert resp.status_code == 200
        worker.refresh_from_db()
        assert worker.user.is_suspended and not worker.is_available
        api.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        assert api.get("/api/v1/auth/me/").status_code == 401
        assert api.post("/api/v1/auth/token/refresh/", {"refresh": tokens["refresh"]}).status_code == 401
        assert client.post(f"{A}users/{worker.user.pk}/reactivate/").status_code == 200
        assert AuditLog.objects.filter(action__in=["user_suspended", "user_reactivated"]).count() == 2

    def test_admin_cannot_suspend_self(self, admin_user):
        assert client_for(admin_user).post(f"{A}users/{admin_user.pk}/suspend/", {"reason": "x"}).status_code == 400


class TestReports:
    def test_revenue_and_dashboard_numbers(self, admin_user, customer, worker, make_booking):
        for price in ("2000", "1000"):
            b = advance_to(make_booking(customer, worker, price), Booking.Status.IN_PROGRESS)
            confirm_completion_by_customer(b, customer)
        make_booking(customer, worker, "500")  # still active
        client = client_for(admin_user)
        revenue = data(client.get(A + "revenue/"))
        assert revenue["completed_bookings"] == 2
        assert revenue["gross_booking_value"] == "3000.00"
        assert revenue["commission_revenue"] == "300.00"
        assert revenue["worker_earnings"] == "2700.00"
        assert len(revenue["monthly"]) == 1

        dash = data(client.get(A + "dashboard/"))
        assert dash["bookings"] == {"completed": 2, "confirmed": 1}
        assert dash["total_commission"] == "300.00"
        assert dash["users"]["customer"] == 1

        reports = data(client.get(A + "reports/"))
        assert reports["bookings_by_category"][0]["category"] == "Electrician"
        assert reports["bookings_by_category"][0]["bookings"] == 3
        assert reports["top_workers"][0]["completed_jobs"] == 2

        commissions = data(client.get(A + "commissions/"))
        assert commissions["count"] == 2
        assert data(client.get(A + "bookings/", {"status": "completed"}))["count"] == 2

    def test_date_filter_validation(self, admin_user):
        resp = client_for(admin_user).get(A + "revenue/", {"date_from": "2026-12-01", "date_to": "2026-01-01"})
        assert resp.status_code == 400


class TestStage2AdminEndpoints:
    @pytest.mark.parametrize("path", ["settings/", "revenue/other/", "subscription-plans/", "featured-plans/",
                                      "subscriptions/", "featured-listings/", "complaints/"])
    def test_admin_only(self, path, admin_user, customer, worker):
        assert client_for(admin_user).get(A + path).status_code == 200
        assert client_for(customer).get(A + path).status_code == 403
        assert client_for(worker.user).get(A + path).status_code == 403

    def test_other_revenue(self, admin_user, api, worker, gateways):
        from apps.billing.models import Payment, SubscriptionPlan
        from conftest import jazzcash_callback

        plan = SubscriptionPlan.objects.get(slug="premium")
        resp = client_for(worker.user).post("/api/v1/subscriptions/", {"plan": plan.pk, "method": "jazzcash"})
        payment = Payment.objects.get(pk=data(resp)["subscription"]["payment"]["id"])
        api.post("/api/v1/payments/callbacks/jazzcash/", jazzcash_callback(payment), format="multipart")
        body = data(client_for(admin_user).get(A + "revenue/other/"))
        assert body["subscription_revenue"] == "3000.00"
        assert body["active_subscriptions"] == {"premium": 1}
