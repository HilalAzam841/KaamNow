import os
from decimal import Decimal

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile

from apps.accounts.models import WorkerDocument
from conftest import LAHORE, client_for, data, make_image

pytestmark = pytest.mark.django_db


class TestWorkerProfile:
    def test_worker_me(self, worker):
        resp = client_for(worker.user).get("/api/v1/workers/me/")
        assert resp.status_code == 200
        body = data(resp)
        assert body["id"] == worker.pk
        assert body["verification_status"] == "verified"
        assert len(body["services"]) == 1

    def test_customer_cannot_access_worker_me(self, customer):
        assert client_for(customer).get("/api/v1/workers/me/").status_code == 403

    def test_update_location_and_radius(self, worker):
        resp = client_for(worker.user).patch("/api/v1/workers/me/", {
            "base_latitude": "31.470000", "base_longitude": "74.270000", "service_radius_km": "15",
            "bio": "10 years of wiring experience", "experience_years": 10, "service_area": "Johar Town",
        })
        assert resp.status_code == 200, resp.json()
        worker.refresh_from_db()
        assert worker.service_radius_km == Decimal("15")
        assert worker.experience_years == 10

    def test_cannot_self_verify_or_change_rating(self, make_worker):
        w = make_worker(verified=False)
        client_for(w.user).patch("/api/v1/workers/me/", {"verification_status": "verified", "average_rating": "5.00"})
        w.refresh_from_db()
        assert w.verification_status == "pending"
        assert w.average_rating == Decimal("0.00")

    def test_radius_validation(self, worker):
        resp = client_for(worker.user).patch("/api/v1/workers/me/", {"service_radius_km": "500"})
        assert resp.status_code == 400

    def test_latitude_and_longitude_together(self, make_worker):
        w = make_worker(lat=None, lng=None)
        resp = client_for(w.user).patch("/api/v1/workers/me/", {"base_latitude": "31.5"})
        assert resp.status_code == 400

    def test_cnic_locked_after_verification(self, worker):
        resp = client_for(worker.user).patch("/api/v1/workers/me/", {"cnic_number": "35202-0000000-1"})
        assert resp.status_code == 400


class TestDocuments:
    URL = "/api/v1/workers/documents/"

    def test_upload_image_document(self, make_worker, settings):
        w = make_worker(verified=False)
        resp = client_for(w.user).post(self.URL, {"document_type": "cnic_front", "file": make_image("front.jpg")},
                                       format="multipart")
        assert resp.status_code == 201, resp.json()
        body = data(resp)
        assert "file" not in body  # private: never returned
        doc = WorkerDocument.objects.get(pk=body["id"])
        # Stored under the private root, not public MEDIA_ROOT.
        assert os.path.commonpath([doc.file.path, str(settings.PRIVATE_MEDIA_ROOT)]) == str(settings.PRIVATE_MEDIA_ROOT)
        with pytest.raises(NotImplementedError):
            _ = doc.file.url

    def test_upload_pdf(self, make_worker):
        w = make_worker(verified=False)
        pdf = SimpleUploadedFile("cnic.pdf", b"%PDF-1.4\n%fake but valid header\n", content_type="application/pdf")
        resp = client_for(w.user).post(self.URL, {"document_type": "cnic_back", "file": pdf}, format="multipart")
        assert resp.status_code == 201

    def test_rejects_disguised_file(self, make_worker):
        w = make_worker(verified=False)
        fake = SimpleUploadedFile("cnic.jpg", b"<?php echo 'x'; ?>", content_type="image/jpeg")
        resp = client_for(w.user).post(self.URL, {"document_type": "cnic_front", "file": fake}, format="multipart")
        assert resp.status_code == 400

    def test_rejects_bad_extension(self, make_worker):
        w = make_worker(verified=False)
        exe = SimpleUploadedFile("cnic.exe", b"MZ....", content_type="application/octet-stream")
        resp = client_for(w.user).post(self.URL, {"document_type": "cnic_front", "file": exe}, format="multipart")
        assert resp.status_code == 400

    def test_rejects_oversized(self, make_worker, settings):
        settings.MAX_DOCUMENT_UPLOAD_MB = 0
        w = make_worker(verified=False)
        resp = client_for(w.user).post(self.URL, {"document_type": "cnic_front", "file": make_image()},
                                       format="multipart")
        assert resp.status_code == 400

    def test_list_only_own_documents(self, make_worker):
        a, b = make_worker(verified=False), make_worker(verified=False)
        client_for(a.user).post(self.URL, {"document_type": "cnic_front", "file": make_image()}, format="multipart")
        assert len(data(client_for(b.user).get(self.URL))) == 0
        assert len(data(client_for(a.user).get(self.URL))) == 1

    def test_customer_cannot_upload(self, customer):
        resp = client_for(customer).post(self.URL, {"document_type": "cnic_front", "file": make_image()},
                                         format="multipart")
        assert resp.status_code == 403


class TestAvailability:
    URL = "/api/v1/workers/availability/"

    def test_verified_worker_goes_online(self, make_worker):
        w = make_worker(available=False)
        resp = client_for(w.user).post(self.URL, {"is_available": True})
        assert resp.status_code == 200
        w.refresh_from_db()
        assert w.is_available

    def test_unverified_cannot_go_online(self, make_worker):
        w = make_worker(verified=False, available=False)
        resp = client_for(w.user).post(self.URL, {"is_available": True})
        assert resp.status_code == 400
        assert "verified" in resp.json()["error"]["message"]

    def test_needs_location(self, make_worker):
        w = make_worker(available=False, lat=None, lng=None)
        assert client_for(w.user).post(self.URL, {"is_available": True}).status_code == 400

    def test_needs_service(self, make_worker):
        w = make_worker(available=False, categories=[])
        assert client_for(w.user).post(self.URL, {"is_available": True}).status_code == 400

    def test_can_always_go_offline(self, make_worker):
        w = make_worker(verified=False, available=True)
        assert client_for(w.user).post(self.URL, {"is_available": False}).status_code == 200


class TestNearbyWorkers:
    URL = "/api/v1/workers/nearby/"

    def test_discovery_filters(self, customer, category, other_category, make_worker):
        near = make_worker(name="Near Worker")                                         # ~0 km
        mid = make_worker(name="Mid Worker", lat=Decimal("31.550000"), lng=Decimal("74.344000"))  # ~4.4 km
        make_worker(name="Far Radius", lat=Decimal("31.650000"), lng=Decimal("74.344000"))        # ~15.6 km > 10
        make_worker(name="Unverified", verified=False)
        make_worker(name="Offline", available=False)
        make_worker(name="Plumber", categories=[other_category])
        suspended = make_worker(name="Suspended")
        suspended.user.is_suspended = True
        suspended.user.save()
        big_radius = make_worker(name="Big Radius", lat=Decimal("31.650000"), lng=Decimal("74.344000"),
                                 radius=Decimal("20"))

        resp = client_for(customer).get(self.URL, {"category": category.pk, "latitude": str(LAHORE[0]),
                                                   "longitude": str(LAHORE[1])})
        assert resp.status_code == 200
        results = data(resp)
        assert [r["id"] for r in results] == [near.pk, mid.pk, big_radius.pk]  # sorted by distance
        assert results[1]["distance_km"] == pytest.approx(4.45, abs=0.1)
        # Public card never leaks private fields.
        assert not {"phone", "cnic_number", "base_latitude", "base_longitude"} & set(results[0])

    def test_validation(self, customer, category):
        resp = client_for(customer).get(self.URL, {"category": category.pk, "latitude": "200", "longitude": "74"})
        assert resp.status_code == 400

    def test_requires_auth(self, api, category):
        assert api.get(self.URL, {"category": category.pk, "latitude": "31.5", "longitude": "74.3"}).status_code == 401

    def test_public_worker_profile(self, api, worker, make_worker):
        assert data(api.get(f"/api/v1/workers/{worker.pk}/"))["full_name"] == worker.user.full_name
        hidden = make_worker(verified=False)
        assert api.get(f"/api/v1/workers/{hidden.pk}/").status_code == 404
