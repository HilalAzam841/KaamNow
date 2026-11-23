import pytest

from apps.catalog.models import ServiceCategory, WorkerService
from apps.dashboard.models import AuditLog
from conftest import client_for, data

pytestmark = pytest.mark.django_db

URL = "/api/v1/services/categories/"


class TestCategories:
    def test_seeded_categories_public(self, api):
        resp = api.get(URL)
        assert resp.status_code == 200
        names = [c["name"] for c in data(resp)]
        assert len(names) == 13
        assert names[0] == "Electrician" and names[-1] == "Other Services"
        assert "Washing Machine Repair" in names

    def test_retrieve(self, api, category):
        assert data(api.get(f"{URL}{category.pk}/"))["slug"] == "electrician"

    def test_admin_create_update_deactivate(self, admin_user, api):
        client = client_for(admin_user)
        resp = client.post(URL, {"name": "Solar Panel Installation", "sort_order": 14})
        assert resp.status_code == 201, resp.json()
        cat_id = data(resp)["id"]
        assert data(resp)["slug"] == "solar-panel-installation"
        resp = client.patch(f"{URL}{cat_id}/", {"is_active": False})
        assert resp.status_code == 200
        # Hidden from the public, visible to admins.
        assert cat_id not in [c["id"] for c in data(api.get(URL))]
        assert cat_id in [c["id"] for c in data(client.get(URL))]
        assert AuditLog.objects.filter(action="category_changed").count() == 2

    def test_duplicate_name(self, admin_user):
        resp = client_for(admin_user).post(URL, {"name": "electrician"})
        assert resp.status_code == 400

    @pytest.mark.parametrize("role", ["customer", "worker"])
    def test_non_admin_cannot_modify(self, role, customer, worker, category):
        user = customer if role == "customer" else worker.user
        client = client_for(user)
        assert client.post(URL, {"name": "Hack"}).status_code == 403
        assert client.patch(f"{URL}{category.pk}/", {"is_active": False}).status_code == 403

    def test_delete_not_allowed(self, admin_user, category):
        assert client_for(admin_user).delete(f"{URL}{category.pk}/").status_code == 405


class TestWorkerServices:
    URL = "/api/v1/services/workers/"

    def test_worker_adds_service(self, make_worker, other_category):
        w = make_worker(categories=[])
        resp = client_for(w.user).post(self.URL, {"category": other_category.pk, "starting_price": "500",
                                                  "description": "Leak fixing"})
        assert resp.status_code == 201, resp.json()
        assert WorkerService.objects.filter(worker=w, category=other_category).exists()

    def test_duplicate_service(self, worker, category):
        resp = client_for(worker.user).post(self.URL, {"category": category.pk})
        assert resp.status_code == 400

    def test_inactive_category(self, worker):
        cat = ServiceCategory.objects.create(name="Dormant", is_active=False)
        assert client_for(worker.user).post(self.URL, {"category": cat.pk}).status_code == 400

    def test_customer_cannot_add(self, customer, category):
        assert client_for(customer).post(self.URL, {"category": category.pk}).status_code == 403

    def test_public_listing_only_verified(self, api, make_worker, category):
        v = make_worker(name="Verified One")
        make_worker(name="Pending One", verified=False)
        resp = api.get(self.URL, {"category": category.pk})
        ids = [r["worker_id"] for r in data(resp)["results"]]
        assert ids == [v.pk]

    def test_worker_mine_listing_and_edit(self, make_worker, worker):
        other = make_worker()
        mine = data(client_for(worker.user).get(self.URL, {"mine": "true"}))["results"]
        assert [m["worker_id"] for m in mine] == [worker.pk]
        service_id = mine[0]["id"]
        assert client_for(worker.user).patch(f"{self.URL}{service_id}/", {"starting_price": "800"}).status_code == 200
        # Another worker cannot edit or delete it.
        assert client_for(other.user).patch(f"{self.URL}{service_id}/", {"starting_price": "1"}).status_code == 404
        assert client_for(other.user).delete(f"{self.URL}{service_id}/").status_code == 404
        assert client_for(worker.user).delete(f"{self.URL}{service_id}/").status_code == 204
