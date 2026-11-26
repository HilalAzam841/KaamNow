import pytest

from apps.addresses.models import SavedAddress
from apps.jobs.models import ServiceRequest
from conftest import client_for, data, request_payload

URL = "/api/v1/addresses/"


def home(**kw):
    return {"label": "home", "address": "House 12, Street 4, Gulberg III", "area": "Gulberg",
            "latitude": "31.512000", "longitude": "74.345000", **kw}


@pytest.mark.django_db
class TestAddresses:
    def test_first_is_default_and_one_home_one_work(self, customer):
        c = client_for(customer)
        first = data(c.post(URL, home(), format="json"))
        assert first["is_default"] is True
        assert c.post(URL, home(), format="json").status_code == 409
        work = data(c.post(URL, home(label="work", address="Office 5, MM Alam Road"), format="json"))
        assert work["is_default"] is False
        assert c.post(URL, home(label="other"), format="json").status_code == 400  # needs a name
        other = data(c.post(URL, home(label="other", name=" Ammi's house ", make_default=True), format="json"))
        assert other["name"] == "Ammi's house" and other["is_default"] is True
        rows = data(c.get(URL))
        assert rows[0]["id"] == other["id"] and sum(r["is_default"] for r in rows) == 1

    def test_make_default_edit_and_delete_moves_default(self, customer):
        c = client_for(customer)
        a = data(c.post(URL, home(), format="json"))
        b = data(c.post(URL, home(label="work", address="Office 5, MM Alam Road"), format="json"))
        assert data(c.post(f"{URL}{b['id']}/make-default/"))["is_default"] is True
        assert SavedAddress.objects.get(pk=a["id"]).is_default is False
        # Changing Work into Home is refused while Home exists.
        assert c.patch(f"{URL}{b['id']}/", {"label": "home"}, format="json").status_code == 409
        assert data(c.patch(f"{URL}{a['id']}/", {"area": "DHA"}, format="json"))["area"] == "DHA"
        assert c.delete(f"{URL}{b['id']}/").status_code == 204
        assert SavedAddress.objects.get(pk=a["id"]).is_default is True

    def test_limit_and_validation(self, customer):
        c = client_for(customer)
        for i in range(10):
            assert c.post(URL, home(label="other", name=f"Place {i}"), format="json").status_code == 201
        assert c.post(URL, home(label="other", name="One more"), format="json").status_code == 400
        assert c.post(URL, home(address="x"), format="json").status_code == 400
        assert c.post(URL, home(latitude="95"), format="json").status_code == 400

    def test_private_to_the_owner(self, customer, make_customer, worker, api):
        a = data(client_for(customer).post(URL, home(), format="json"))
        other = client_for(make_customer())
        assert data(other.get(URL)) == []
        for call in (other.get, other.delete):
            assert call(f"{URL}{a['id']}/").status_code == 404
        assert other.post(f"{URL}{a['id']}/make-default/").status_code == 404
        assert client_for(worker.user).get(URL).status_code == 403
        assert api.get(URL).status_code == 401


@pytest.mark.django_db
class TestPostingFromASavedAddress:
    def test_saved_address_fills_the_location(self, customer, category):
        a = data(client_for(customer).post(URL, home(), format="json"))
        body = request_payload(category)
        for k in ("latitude", "longitude", "address", "area"):
            body.pop(k, None)
        resp = client_for(customer).post("/api/v1/requests/", {**body, "saved_address": a["id"]}, format="json")
        assert resp.status_code == 201, resp.json()
        req = ServiceRequest.objects.get(pk=data(resp)["id"])
        assert req.address == "House 12, Street 4, Gulberg III" and req.area == "Gulberg"
        assert str(req.latitude) == "31.512000"

    def test_someone_elses_saved_address_is_refused(self, customer, make_customer, category):
        a = data(client_for(make_customer()).post(URL, home(), format="json"))
        body = request_payload(category)
        resp = client_for(customer).post("/api/v1/requests/", {**body, "saved_address": a["id"]}, format="json")
        assert resp.status_code == 400
        assert ServiceRequest.objects.count() == 0

    def test_location_still_required_without_one(self, customer, category):
        body = request_payload(category)
        body.pop("latitude")
        assert client_for(customer).post("/api/v1/requests/", body, format="json").status_code == 400
