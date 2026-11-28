from datetime import timedelta

import pytest
from django.conf import settings
from django.utils import timezone

from apps.dashboard.models import AuditLog
from apps.jobphotos.models import MAX_PHOTOS_PER_KIND, JobPhoto
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from conftest import advance_to, client_for, data, make_image

pytestmark = pytest.mark.django_db


def url(booking, suffix=""):
    return f"/api/v1/bookings/{booking.pk}/photos/{suffix}"


def upload(user, booking, kind="before", caption=""):
    return client_for(user).post(url(booking), {"kind": kind, "image": make_image(), "caption": caption},
                                 format="multipart")


def start(booking):
    from apps.jobs.services import update_booking_status

    return update_booking_status(booking, booking.worker.user, Booking.Status.IN_PROGRESS)


@pytest.fixture
def arrived(customer, worker, make_booking):
    return advance_to(make_booking(customer, worker), Booking.Status.ARRIVED)


class TestUpload:
    def test_worker_adds_before_then_after_and_customer_sees_both(self, customer, worker, arrived):
        resp = upload(worker.user, arrived, "before", "Broken switch board")
        assert resp.status_code == 201, resp.content
        assert data(resp)["kind"] == "before" and data(resp)["caption"] == "Broken switch board"
        assert upload(worker.user, arrived, "after").status_code == 409  # work not started yet

        booking = start(arrived)
        assert upload(worker.user, booking, "after").status_code == 201
        body = data(client_for(customer).get(url(booking)))
        assert [p["kind"] for p in body["results"]] == ["before", "after"]
        assert body["summary"]["before"] == 1 and body["summary"]["after"] == 1
        assert body["summary"]["can_add_before"] is False  # the customer cannot add

        file_resp = client_for(customer).get(body["results"][0]["file_url"])
        assert file_resp.status_code == 200
        assert file_resp["Content-Type"] == "image/jpeg"
        assert "no-store" in file_resp["Cache-Control"]

    def test_photos_are_private_files_without_location_data(self, worker, arrived):
        upload(worker.user, arrived)
        photo = JobPhoto.objects.get()
        assert str(settings.PRIVATE_MEDIA_ROOT) in photo.image.path
        with pytest.raises(NotImplementedError):
            photo.image.url  # noqa: B018 - private files have no public URL

    def test_before_not_allowed_until_arrived(self, customer, worker, make_booking):
        booking = make_booking(customer, worker)
        resp = upload(worker.user, booking)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "job_photo_not_now"
        booking = advance_to(booking, Booking.Status.ON_THE_WAY)
        assert upload(worker.user, booking).status_code == 409

    def test_limit_per_kind(self, worker, arrived):
        for _ in range(MAX_PHOTOS_PER_KIND):
            assert upload(worker.user, arrived).status_code == 201
        resp = upload(worker.user, arrived)
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "job_photo_limit"
        summary = data(client_for(worker.user).get(url(arrived)))["summary"]
        assert summary["can_add_before"] is False

    def test_only_the_worker_adds(self, customer, arrived):
        assert upload(customer, arrived).status_code == 403

    def test_outsiders_get_404(self, worker, arrived, make_customer, make_worker):
        upload(worker.user, arrived)
        photo = JobPhoto.objects.get()
        for user in (make_customer(), make_worker().user):
            c = client_for(user)
            assert c.get(url(arrived)).status_code == 404
            assert c.get(url(arrived, f"{photo.pk}/file/")).status_code == 404
            assert upload(user, arrived).status_code == 404

    def test_anonymous_is_rejected(self, api, arrived):
        assert api.get(url(arrived)).status_code == 401

    def test_rejects_non_images(self, worker, arrived):
        from django.core.files.uploadedfile import SimpleUploadedFile

        bad = SimpleUploadedFile("x.jpg", b"not an image", content_type="image/jpeg")
        resp = client_for(worker.user).post(url(arrived), {"kind": "before", "image": bad}, format="multipart")
        assert resp.status_code == 400

    def test_customer_notified_once_on_first_after_photo(self, customer, worker, arrived):
        booking = start(arrived)
        upload(worker.user, booking, "after")
        upload(worker.user, booking, "after")
        notes = Notification.objects.filter(user=customer, data__booking_id=booking.pk,
                                            title__icontains="photos of the finished work")
        assert notes.count() == 1


class TestAfterCompletion:
    def test_after_photos_for_24_hours_then_locked(self, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        assert upload(worker.user, booking, "after").status_code == 201
        assert upload(worker.user, booking, "before").status_code == 409
        photo = JobPhoto.objects.get()
        Booking.objects.filter(pk=booking.pk).update(completed_at=timezone.now() - timedelta(hours=25))
        assert upload(worker.user, booking, "after").status_code == 409
        resp = client_for(worker.user).delete(url(booking, f"{photo.pk}/"))
        assert resp.status_code == 409 and resp.json()["error"]["code"] == "job_photo_locked"
        assert client_for(customer).get(url(booking, f"{photo.pk}/file/")).status_code == 200

    def test_booking_shows_photo_summary(self, customer, worker, arrived):
        upload(worker.user, arrived)
        worker_view = data(client_for(worker.user).get(f"/api/v1/bookings/{arrived.pk}/"))["job_photos"]
        assert worker_view == {"before": 1, "after": 0, "max_per_kind": MAX_PHOTOS_PER_KIND,
                               "can_add_before": True, "can_add_after": False}
        customer_view = data(client_for(customer).get(f"/api/v1/bookings/{arrived.pk}/"))["job_photos"]
        assert customer_view["can_add_before"] is False


class TestDelete:
    def test_worker_removes_own_photo(self, customer, worker, arrived):
        upload(worker.user, arrived)
        photo = JobPhoto.objects.get()
        path = photo.image.path
        assert client_for(customer).delete(url(arrived, f"{photo.pk}/")).status_code == 403
        assert client_for(worker.user).delete(url(arrived, f"{photo.pk}/")).status_code == 204
        assert not JobPhoto.objects.exists()
        import os

        assert not os.path.exists(path)


class TestAdmin:
    def test_admin_lists_and_each_view_is_audited(self, worker, arrived, admin_user, customer):
        upload(worker.user, arrived)
        a = client_for(admin_user)
        photos = data(a.get(f"/api/v1/admin/bookings/{arrived.pk}/photos/"))
        assert photos[0]["file_url"] == f"/api/v1/admin/bookings/{arrived.pk}/photos/{photos[0]['id']}/file/"
        assert not AuditLog.objects.filter(action=AuditLog.Action.JOB_PHOTO_VIEWED).exists()
        assert a.get(photos[0]["file_url"]).status_code == 200
        log = AuditLog.objects.get(action=AuditLog.Action.JOB_PHOTO_VIEWED)
        assert log.actor == admin_user and log.metadata["booking_id"] == arrived.pk
        assert client_for(customer).get(f"/api/v1/admin/bookings/{arrived.pk}/photos/").status_code == 403
