from datetime import timedelta

import pytest
from django.utils import timezone

from apps.billing.models import PlatformSettings
from apps.chat.models import ChatMessage
from apps.guarantee.models import GuaranteeClaim
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.support.models import Complaint
from conftest import client_for, data

pytestmark = pytest.mark.django_db

PROBLEM = "The fan stopped working again after two days"


def claim_url(booking):
    return f"/api/v1/bookings/{booking.pk}/guarantee/"


def url(claim, action=""):
    return f"/api/v1/guarantee-claims/{claim['id']}/{action + '/' if action else ''}"


def make_claim(customer, booking, problem=PROBLEM):
    return client_for(customer).post(claim_url(booking), {"problem": problem})


@pytest.fixture
def done(customer, worker, completed_booking_factory):
    return completed_booking_factory(customer, worker)


def later(hours=24):
    return (timezone.now() + timedelta(hours=hours)).isoformat()


class TestClaim:
    def test_happy_path_accept_redo_confirm(self, customer, worker, done):
        before = data(client_for(customer).get(f"/api/v1/bookings/{done.pk}/"))["guarantee"]
        assert before["can_claim"] is True and before["claim"] is None and before["until"]
        assert data(client_for(worker.user).get(f"/api/v1/bookings/{done.pk}/"))["guarantee"]["can_claim"] is False

        resp = make_claim(customer, done)
        assert resp.status_code == 201, resp.content
        claim = data(resp)
        assert claim["status"] == "pending" and claim["can_escalate"] is False
        assert Notification.objects.filter(user=worker.user, data__guarantee_claim_id=claim["id"]).exists()

        w = client_for(worker.user)
        claim = data(w.post(url(claim, "accept"), {"redo_time": later(), "note": "Will bring a new capacitor"}))
        assert claim["status"] == "accepted" and claim["worker_note"] == "Will bring a new capacitor"
        assert data(w.post(url(claim, "redo-done")))["status"] == "redo_done"
        claim = data(client_for(customer).post(url(claim, "confirm-fixed")))
        assert claim["status"] == "fixed" and claim["closed_at"]
        after = data(client_for(customer).get(f"/api/v1/bookings/{done.pk}/"))["guarantee"]
        assert after["can_claim"] is False and after["claim"]["status"] == "fixed"

    def test_once_per_booking(self, customer, done):
        make_claim(customer, done)
        resp = make_claim(customer, done)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "guarantee_already_claimed"

    def test_only_after_completion_and_within_window(self, customer, worker, make_booking, done):
        active = make_booking(customer, worker)
        assert make_claim(customer, active).json()["error"]["code"] == "guarantee_not_completed"
        Booking.objects.filter(pk=done.pk).update(completed_at=timezone.now() - timedelta(days=8))
        resp = make_claim(customer, done)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "guarantee_expired"

    def test_admin_sets_window_and_can_switch_off(self, customer, done):
        cfg = PlatformSettings.load()
        cfg.guarantee_days = 30
        cfg.save()
        Booking.objects.filter(pk=done.pk).update(completed_at=timezone.now() - timedelta(days=20))
        assert make_claim(customer, done).status_code == 201
        GuaranteeClaim.objects.all().delete()
        cfg.guarantee_enabled = False
        cfg.save()
        assert make_claim(customer, done).json()["error"]["code"] == "guarantee_disabled"
        assert data(client_for(customer).get("/api/v1/app/config/"))["guarantee"] == {"enabled": False, "days": 30}

    def test_only_the_customer_claims_and_outsiders_get_404(self, worker, done, make_customer):
        assert make_claim(worker.user, done).status_code == 403
        assert make_claim(make_customer(), done).status_code == 404

    def test_problem_must_be_described(self, customer, done):
        assert make_claim(customer, done, "broken").status_code == 400


class TestWorkerAnswer:
    def test_decline_then_customer_escalates_to_complaint(self, customer, worker, done):
        claim = data(make_claim(customer, done))
        assert client_for(worker.user).post(url(claim, "decline"), {"reason": "short"}).status_code == 400
        claim = data(client_for(worker.user).post(
            url(claim, "decline"), {"reason": "The fan motor burnt out, not my repair"}))
        assert claim["status"] == "declined" and claim["can_escalate"] is True
        claim = data(client_for(customer).post(url(claim, "escalate"), {"details": "It is the same fault"}))
        assert claim["status"] == "escalated" and claim["complaint_id"]
        complaint = Complaint.objects.get(pk=claim["complaint_id"])
        assert complaint.category == "guarantee" and complaint.booking_id == done.pk
        assert complaint.against_user == worker.user
        assert "not my repair" in complaint.description and "same fault" in complaint.description

    def test_escalate_only_after_worker_had_48_hours(self, customer, done):
        claim = data(make_claim(customer, done))
        resp = client_for(customer).post(url(claim, "escalate"))
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "guarantee_wait_for_worker"
        GuaranteeClaim.objects.filter(pk=claim["id"]).update(respond_by=timezone.now() - timedelta(minutes=1))
        assert data(client_for(customer).post(url(claim, "escalate")))["status"] == "escalated"

    def test_redo_time_must_be_soon(self, customer, worker, done):
        claim = data(make_claim(customer, done))
        w = client_for(worker.user)
        assert w.post(url(claim, "accept"), {"redo_time": later(24 * 30)}).status_code == 400
        assert w.post(url(claim, "accept"), {"redo_time": later(-24)}).status_code == 400

    def test_roles_are_enforced(self, customer, worker, done):
        claim = data(make_claim(customer, done))
        assert client_for(customer).post(url(claim, "accept"), {"redo_time": later()}).status_code == 403
        assert client_for(worker.user).post(url(claim, "confirm-fixed")).status_code == 403
        assert client_for(worker.user).post(url(claim, "withdraw")).status_code == 403

    def test_answering_twice_conflicts(self, customer, worker, done):
        claim = data(make_claim(customer, done))
        w = client_for(worker.user)
        w.post(url(claim, "accept"), {"redo_time": later()})
        resp = w.post(url(claim, "decline"), {"reason": "Changed my mind about this"})
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "guarantee_not_pending"

    def test_customer_withdraws(self, customer, done):
        claim = data(make_claim(customer, done))
        assert data(client_for(customer).post(url(claim, "withdraw")))["status"] == "withdrawn"
        assert client_for(customer).post(url(claim, "withdraw")).status_code == 409


class TestVisibility:
    def test_lists_are_per_user(self, customer, worker, done, make_customer, admin_user):
        claim = data(make_claim(customer, done))
        assert [c["id"] for c in data(client_for(customer).get("/api/v1/guarantee-claims/"))["results"]] == [claim["id"]]
        assert [c["id"] for c in data(client_for(worker.user).get("/api/v1/guarantee-claims/"))["results"]] == [claim["id"]]
        other = client_for(make_customer())
        assert data(other.get("/api/v1/guarantee-claims/"))["results"] == []
        assert other.get(url(claim)).status_code == 404
        assert other.post(url(claim, "withdraw")).status_code == 404
        admin_list = data(client_for(admin_user).get("/api/v1/admin/guarantee-claims/?status=pending"))["results"]
        assert [c["id"] for c in admin_list] == [claim["id"]]
        assert client_for(customer).get("/api/v1/admin/guarantee-claims/").status_code == 403

    def test_chat_reopens_while_claim_is_open(self, customer, worker, done):
        Booking.objects.filter(pk=done.pk).update(completed_at=timezone.now() - timedelta(days=3))
        chat = f"/api/v1/bookings/{done.pk}/messages/"
        assert client_for(customer).post(chat, {"body": "Hello"}).status_code == 409
        claim = data(make_claim(customer, done))
        assert client_for(customer).post(chat, {"body": "The fan stopped again"}).status_code == 201
        client_for(customer).post(url(claim, "withdraw"))
        assert client_for(customer).post(chat, {"body": "Never mind"}).status_code == 409
        assert ChatMessage.objects.count() == 1
