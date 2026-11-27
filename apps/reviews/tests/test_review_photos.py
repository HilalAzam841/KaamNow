import io

import pytest
from PIL import Image

from apps.dashboard.models import AuditLog
from apps.jobs.models import Booking
from apps.jobs.services import confirm_completion_by_customer
from apps.notifications.models import Notification
from apps.reviews.models import Review, ReviewPhoto
from conftest import advance_to, client_for, data, make_image

pytestmark = pytest.mark.django_db


def complete(booking, customer):
    return confirm_completion_by_customer(advance_to(booking, Booking.Status.IN_PROGRESS), customer)


@pytest.fixture
def review(customer, worker, make_booking):
    b = complete(make_booking(customer, worker), customer)
    rid = data(client_for(customer).post("/api/v1/reviews/", {"booking": b.pk, "rating": 4, "comment": "Good"}))["id"]
    return Review.objects.get(pk=rid)


def upload(user, review, img=None):
    return client_for(user).post(f"/api/v1/reviews/{review.pk}/photos/", {"image": img or make_image()},
                                 format="multipart")


def gps_jpeg():
    from django.core.files.uploadedfile import SimpleUploadedFile

    img = Image.new("RGB", (40, 30), "red")
    exif = Image.Exif()
    exif[0x010F] = "PhoneCam"
    exif[0x8825] = {1: "N", 2: (31.0, 30.0, 0.0), 3: "E", 4: (74.0, 20.0, 0.0)}
    out = io.BytesIO()
    img.save(out, format="JPEG", exif=exif)
    return SimpleUploadedFile("gps.jpg", out.getvalue(), content_type="image/jpeg")


class TestPhotos:
    def test_customer_adds_photos_without_location_data(self, customer, review):
        r = upload(customer, review, gps_jpeg())
        assert r.status_code == 201, r.json()
        photo = ReviewPhoto.objects.get(pk=data(r)["id"])
        with Image.open(photo.image.path) as img:
            exif = img.getexif()
            assert not exif.get_ifd(0x8825) and 0x010F not in exif, "GPS and camera data must be stripped"

    def test_up_to_three(self, customer, review):
        for _ in range(3):
            assert upload(customer, review).status_code == 201
        r = upload(customer, review)
        assert r.status_code == 409 and r.json()["error"]["code"] == "too_many_photos"

    def test_only_the_author(self, worker, make_customer, review):
        assert upload(worker.user, review).status_code == 403
        assert upload(make_customer(), review).status_code == 403

    def test_rejects_non_images(self, customer, review):
        from django.core.files.uploadedfile import SimpleUploadedFile

        fake = SimpleUploadedFile("x.jpg", b"not an image", content_type="image/jpeg")
        assert upload(customer, review, fake).status_code == 400

    def test_author_deletes_a_photo(self, customer, worker, review):
        pid = data(upload(customer, review))["id"]
        assert client_for(worker.user).delete(f"/api/v1/reviews/{review.pk}/photos/{pid}/").status_code == 403
        assert client_for(customer).delete(f"/api/v1/reviews/{review.pk}/photos/{pid}/").status_code == 204
        assert not ReviewPhoto.objects.filter(pk=pid).exists()

    def test_public_list_shows_photos_and_filters(self, api, customer, worker, make_customer, make_booking, review):
        upload(customer, review)
        other = make_customer()
        b2 = complete(make_booking(other, worker), other)
        client_for(other).post("/api/v1/reviews/", {"booking": b2.pk, "rating": 5})
        rows = data(api.get(f"/api/v1/workers/{worker.pk}/reviews/"))["results"]
        assert len(rows) == 2
        with_photos = data(api.get(f"/api/v1/workers/{worker.pk}/reviews/?with_photos=true"))["results"]
        assert [r["id"] for r in with_photos] == [review.pk]
        assert with_photos[0]["photos"][0]["image"].startswith("http")
        assert with_photos[0]["can_reply"] is False


class TestReply:
    def test_worker_replies_once_and_customer_is_told(self, api, customer, worker, review):
        rows = data(client_for(worker.user).get(f"/api/v1/workers/{worker.pk}/reviews/"))["results"]
        assert rows[0]["can_reply"] is True
        r = client_for(worker.user).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Thank you, Ayesha!"})
        body = data(r)
        assert body["reply"] == "Thank you, Ayesha!" and body["replied_at"] and body["can_reply"] is False
        assert Notification.objects.filter(user=customer, title="The worker replied to your review").exists()
        r = client_for(worker.user).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Again"})
        assert r.status_code == 409 and r.json()["error"]["code"] == "already_replied"
        assert data(api.get(f"/api/v1/workers/{worker.pk}/reviews/"))["results"][0]["reply"] == "Thank you, Ayesha!"

    def test_only_the_reviewed_worker(self, customer, make_worker, review):
        assert client_for(customer).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Hi"}).status_code == 403
        other = make_worker()
        assert client_for(other.user).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Hi"}).status_code == 403

    def test_reply_length(self, worker, review):
        url = f"/api/v1/reviews/{review.pk}/reply/"
        assert client_for(worker.user).post(url, {"reply": " "}).status_code == 400
        assert client_for(worker.user).post(url, {"reply": "x" * 501}).status_code == 400


class TestAdmin:
    def test_hide_review_drops_it_and_its_rating(self, api, admin_user, worker, review):
        r = client_for(admin_user).post(f"/api/v1/admin/reviews/{review.pk}/hide/", {"reason": "Abusive language"})
        assert data(r)["is_visible"] is False
        worker.refresh_from_db()
        assert worker.rating_count == 0
        assert data(api.get(f"/api/v1/workers/{worker.pk}/reviews/"))["results"] == []
        assert client_for(worker.user).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Hi"}).status_code == 404
        client_for(admin_user).post(f"/api/v1/admin/reviews/{review.pk}/unhide/")
        worker.refresh_from_db()
        assert worker.rating_count == 1
        assert AuditLog.objects.filter(action=AuditLog.Action.REVIEW_MODERATED).count() == 2

    def test_hide_a_photo_and_remove_a_reply(self, api, admin_user, customer, worker, review):
        pid = data(upload(customer, review))["id"]
        client_for(worker.user).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Rude reply"})
        admin = client_for(admin_user)
        body = data(admin.post(f"/api/v1/admin/reviews/{review.pk}/photos/{pid}/hide/", {"reason": "Shows a face"}))
        assert body["photos"][0]["is_hidden"] is True
        body = data(admin.post(f"/api/v1/admin/reviews/{review.pk}/remove-reply/", {"reason": "Insulting"}))
        assert body["reply"] == ""
        row = data(api.get(f"/api/v1/workers/{worker.pk}/reviews/"))["results"][0]
        assert row["photos"] == [] and row["reply"] == ""
        assert client_for(worker.user).post(f"/api/v1/reviews/{review.pk}/reply/", {"reply": "Sorry, thanks"}).status_code == 200
        assert AuditLog.objects.filter(action=AuditLog.Action.REVIEW_MODERATED).count() == 2

    def test_admin_only_and_filters(self, admin_user, customer, review):
        assert client_for(customer).get("/api/v1/admin/reviews/").status_code == 403
        assert data(client_for(admin_user).get("/api/v1/admin/reviews/?with_photos=true"))["results"] == []
        upload(customer, review)
        rows = data(client_for(admin_user).get("/api/v1/admin/reviews/?with_photos=true"))["results"]
        assert rows[0]["customer_name"] == customer.full_name
        assert client_for(admin_user).post(f"/api/v1/admin/reviews/{review.pk}/hide/", {"reason": "x"}).status_code == 400
