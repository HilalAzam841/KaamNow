import io

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

from apps.dashboard.models import AuditLog
from apps.notifications.models import Notification
from apps.portfolio import services
from apps.portfolio.models import PortfolioPhoto
from conftest import client_for, data, make_image

MINE = "/api/v1/workers/me/portfolio/"


def gps_photo(size=(3000, 2000)):
    """A JPEG with a GPS position and camera make in its EXIF, rotated by its orientation tag."""
    img = Image.new("RGB", size, (200, 30, 30))
    exif = Image.Exif()
    exif[0x010F] = "PhoneCam"  # Make
    exif[0x0112] = 6  # Orientation: rotate 90
    exif[0x8825] = {1: "N", 2: (31.0, 30.0, 0.0), 3: "E", 4: (74.0, 20.0, 0.0)}  # GPS
    buf = io.BytesIO()
    img.save(buf, format="JPEG", exif=exif)
    return SimpleUploadedFile("job.jpg", buf.getvalue(), content_type="image/jpeg")


def upload(worker, image=None, **fields):
    return client_for(worker.user).post(MINE, {"image": image or make_image(), **fields}, format="multipart")


@pytest.mark.django_db
class TestUpload:
    def test_upload_strips_location_and_shrinks(self, worker):
        resp = upload(worker, gps_photo(), caption=" New wiring in a kitchen ")
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert body["caption"] == "New wiring in a kitchen" and body["is_hidden"] is False
        photo = PortfolioPhoto.objects.get()
        with Image.open(photo.image.path) as saved:
            assert max(saved.size) == services.MAX_SIDE
            assert saved.size[1] > saved.size[0]  # turned upright from the orientation tag
            exif = saved.getexif()
            assert not exif.get_ifd(0x8825) and 0x010F not in exif and 0x0112 not in exif

    def test_transparent_png_stays_png(self, worker):
        buf = io.BytesIO()
        Image.new("RGBA", (40, 40), (0, 0, 0, 0)).save(buf, format="PNG")
        resp = upload(worker, SimpleUploadedFile("logo.png", buf.getvalue(), content_type="image/png"))
        assert resp.status_code == 201
        assert PortfolioPhoto.objects.get().image.name.endswith(".png")

    def test_fake_and_wrong_files_are_refused(self, worker):
        fake = SimpleUploadedFile("job.jpg", b"not an image at all", content_type="image/jpeg")
        assert upload(worker, fake).status_code == 400
        buf = io.BytesIO()
        Image.new("RGB", (20, 20)).save(buf, format="GIF")
        gif = SimpleUploadedFile("anim.gif", buf.getvalue(), content_type="image/gif")
        assert upload(worker, gif).status_code == 400
        assert PortfolioPhoto.objects.count() == 0

    def test_limit_of_12(self, worker):
        for _ in range(services.MAX_PHOTOS):
            assert upload(worker).status_code == 201
        assert upload(worker).status_code == 409

    def test_category_must_be_one_of_their_services(self, worker, category, other_category):
        assert upload(worker, category=category.pk).status_code == 201
        assert upload(worker, category=other_category.pk).status_code == 400

    def test_linked_job_must_be_their_finished_job(self, worker, make_worker, customer, completed_booking_factory,
                                                   make_booking):
        done = completed_booking_factory(customer, worker)
        resp = upload(worker, booking=done.pk)
        assert data(resp)["from_job"] is True and data(resp)["category"] == done.request.category_id
        other = make_worker()
        assert upload(other, booking=done.pk).status_code == 400
        open_booking = make_booking(customer, worker)
        assert upload(worker, booking=open_booking.pk).status_code == 400

    def test_only_workers(self, customer, api):
        assert client_for(customer).post(MINE, {"image": make_image()}, format="multipart").status_code == 403
        assert api.get(MINE).status_code == 401


@pytest.mark.django_db
class TestManage:
    def test_edit_reorder_delete(self, worker, make_worker):
        ids = [data(upload(worker, caption=f"P{i}"))["id"] for i in range(3)]
        c = client_for(worker.user)
        assert data(c.patch(f"{MINE}{ids[0]}/", {"caption": "Bathroom tiles"}, format="json"))["caption"] == "Bathroom tiles"
        new = [ids[2], ids[0], ids[1]]
        assert [p["id"] for p in data(c.post(f"{MINE}reorder/", {"ids": new}, format="json"))] == new
        assert [p["id"] for p in data(c.get(MINE))] == new
        assert c.post(f"{MINE}reorder/", {"ids": ids[:2]}, format="json").status_code == 400
        # Someone else cannot touch them.
        other = client_for(make_worker().user)
        assert other.delete(f"{MINE}{ids[0]}/").status_code == 404
        assert other.patch(f"{MINE}{ids[0]}/", {"caption": "x"}, format="json").status_code == 404
        path = PortfolioPhoto.objects.get(pk=ids[0]).image.path
        assert c.delete(f"{MINE}{ids[0]}/").status_code == 204
        import os

        assert not os.path.exists(path)


@pytest.mark.django_db
class TestPublicAndAdmin:
    def test_profile_shows_visible_photos_and_admin_can_hide(self, worker, customer, admin_user, api):
        first = data(upload(worker, caption="Ceiling fan"))["id"]
        second = data(upload(worker, caption="Rude words here"))["id"]
        profile = data(client_for(customer).get(f"/api/v1/workers/{worker.pk}/"))
        assert [p["id"] for p in profile["portfolio"]] == [first, second]
        assert "is_hidden" not in profile["portfolio"][0] and "booking" not in profile["portfolio"][0]
        assert len(data(api.get(f"/api/v1/workers/{worker.pk}/portfolio/"))) == 2

        a = client_for(admin_user)
        assert data(a.get("/api/v1/admin/portfolio-photos/"))["results"][0]["worker_name"] == worker.user.full_name
        assert a.post(f"/api/v1/admin/portfolio-photos/{second}/hide/", {"reason": ""}, format="json").status_code == 400
        resp = a.post(f"/api/v1/admin/portfolio-photos/{second}/hide/", {"reason": "Not a work photo"}, format="json")
        assert data(resp)["is_hidden"] is True
        note = Notification.objects.get(user=worker.user, data__portfolio_photo_id=second)
        assert "Not a work photo" in note.body
        assert [p["id"] for p in data(api.get(f"/api/v1/workers/{worker.pk}/portfolio/"))] == [first]
        # The worker still sees it, with the reason.
        mine = {p["id"]: p for p in data(client_for(worker.user).get(MINE))}
        assert mine[second]["hidden_reason"] == "Not a work photo"
        a.post(f"/api/v1/admin/portfolio-photos/{second}/unhide/")
        assert len(data(api.get(f"/api/v1/workers/{worker.pk}/portfolio/"))) == 2
        assert AuditLog.objects.filter(action=AuditLog.Action.PORTFOLIO_MODERATED).count() == 2
        assert client_for(customer).get("/api/v1/admin/portfolio-photos/").status_code == 403

    def test_unverified_workers_have_no_public_portfolio(self, make_worker, api):
        w = make_worker(verified=False)
        upload(w)
        assert api.get(f"/api/v1/workers/{w.pk}/portfolio/").status_code == 404

    def test_hidden_notice_in_the_workers_language(self, worker, admin_user):
        worker.user.language = "ur"
        worker.user.save()
        pid = data(upload(worker))["id"]
        client_for(admin_user).post(f"/api/v1/admin/portfolio-photos/{pid}/hide/", {"reason": "Blurry"}, format="json")
        note = Notification.objects.get(user=worker.user)
        assert "Blurry" in note.body and "چھپا" in note.title
