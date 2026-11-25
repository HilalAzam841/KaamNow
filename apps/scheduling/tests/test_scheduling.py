from datetime import datetime, time, timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.jobs.services import find_nearby_workers, open_requests_for_worker
from apps.notifications.models import Notification
from apps.offers.services import accept_offer, create_offer
from apps.scheduling import services
from apps.scheduling.models import TimeOff, WorkingHours
from conftest import LAHORE, client_for, data, request_payload

SCHEDULE = "/api/v1/workers/me/schedule/"
TIME_OFF = "/api/v1/workers/me/time-off/"
SLOTS = "/api/v1/requests/slots/"


def local(day, hh, mm=0):
    return datetime.combine(day, time(hh, mm), tzinfo=timezone.get_current_timezone())


def next_weekday(weekday, weeks=1):
    today = timezone.localdate()
    return today + timedelta(days=(weekday - today.weekday()) % 7 + 7 * weeks)


def set_hours(worker, *days, start=time(9), end=time(17)):
    for d in days:
        WorkingHours.objects.create(worker=worker, weekday=d, start_time=start, end_time=end)


def offer(worker, req, price="1000"):
    return create_offer(worker, req, price=Decimal(price), estimated_arrival_minutes=30, message="I can come")


MONDAY = 0
TUESDAY = 1


@pytest.mark.django_db
class TestFreeRules:
    def test_no_hours_means_any_time(self, worker, customer, make_request):
        day = next_weekday(MONDAY)
        req = make_request(customer, preferred_time=local(day, 22))
        assert services.why_not_free(worker, req) is None

    def test_inside_and_outside_hours(self, worker, customer, make_request):
        set_hours(worker, MONDAY)
        day = next_weekday(MONDAY)
        assert services.why_not_free(worker, make_request(customer, preferred_time=local(day, 10))) is None
        # 16:00 + 2 hours runs past 17:00.
        assert services.why_not_free(worker, make_request(customer, preferred_time=local(day, 16))) == "off_hours"
        # Tuesday is not a working day.
        tue = next_weekday(TUESDAY)
        assert services.why_not_free(worker, make_request(customer, preferred_time=local(tue, 10))) == "off_hours"

    def test_time_off(self, worker, customer, make_request):
        day = next_weekday(MONDAY)
        TimeOff.objects.create(worker=worker, start_date=day, end_date=day + timedelta(days=2))
        assert services.why_not_free(worker, make_request(customer, preferred_time=local(day, 10))) == "time_off"
        later = make_request(customer, preferred_time=local(day + timedelta(days=3), 10))
        assert services.why_not_free(worker, later) is None

    def test_busy_with_overlapping_booking(self, worker, customer, make_request):
        day = next_weekday(MONDAY)
        first = make_request(customer, preferred_time=local(day, 10))
        accept_offer(offer(worker, first), customer)
        overlap = make_request(customer, preferred_time=local(day, 11))
        after = make_request(customer, preferred_time=local(day, 12))
        assert services.why_not_free(worker, overlap) == "busy"
        assert services.why_not_free(worker, after) is None

    def test_longer_duration_counts(self, worker, customer, make_request):
        day = next_weekday(MONDAY)
        first = make_request(customer, preferred_time=local(day, 10))
        first.duration_minutes = 240
        first.save()
        accept_offer(offer(worker, first), customer)
        assert services.why_not_free(worker, make_request(customer, preferred_time=local(day, 13))) == "busy"

    def test_emergency_skips_hours_and_time_off(self, worker, customer, make_request):
        set_hours(worker, (timezone.localdate().weekday() + 3) % 7)  # not today
        today = timezone.localdate()
        TimeOff.objects.create(worker=worker, start_date=today, end_date=today)
        req = make_request(customer)
        req.is_emergency = True
        req.save()
        assert services.why_not_free(worker, req) is None


@pytest.mark.django_db
class TestMatchingAndOffers:
    def test_only_free_workers_are_notified(self, make_worker, customer, category, django_capture_on_commit_callbacks):
        free = make_worker(name="Free")
        off = make_worker(name="Off")
        set_hours(off, TUESDAY)
        day = next_weekday(MONDAY)
        with django_capture_on_commit_callbacks(execute=True):
            resp = client_for(customer).post(
                "/api/v1/requests/", request_payload(category, preferred_time=local(day, 10).isoformat()), format="json"
            )
        assert resp.status_code == 201, resp.json()
        notified = set(Notification.objects.filter(type=Notification.Type.NEW_REQUEST).values_list("user_id", flat=True))
        assert free.user_id in notified and off.user_id not in notified

    def test_emergency_reaches_off_hours_workers(self, make_worker, customer, category,
                                                 django_capture_on_commit_callbacks):
        off = make_worker()
        set_hours(off, (timezone.localdate().weekday() + 3) % 7)
        with django_capture_on_commit_callbacks(execute=True):
            resp = client_for(customer).post("/api/v1/requests/", request_payload(category, is_emergency=True),
                                             format="json")
        assert resp.status_code == 201, resp.json()
        assert Notification.objects.filter(user=off.user, type=Notification.Type.NEW_REQUEST).exists()

    def test_find_nearby_with_window(self, make_worker, category):
        a, b = make_worker(name="A"), make_worker(name="B")
        day = next_weekday(MONDAY)
        TimeOff.objects.create(worker=b, start_date=day, end_date=day)
        window = (local(day, 10), local(day, 12))
        assert {w.pk for w in find_nearby_workers(category, *LAHORE, window=window)} == {a.pk}
        assert {w.pk for w in find_nearby_workers(category, *LAHORE)} == {a.pk, b.pk}

    def test_feed_hides_jobs_worker_is_not_free_for(self, worker, customer, make_request):
        set_hours(worker, MONDAY)
        mon = make_request(customer, preferred_time=local(next_weekday(MONDAY), 10))
        tue = make_request(customer, preferred_time=local(next_weekday(TUESDAY), 10))
        ids = {r.pk for r in open_requests_for_worker(worker)}
        assert mon.pk in ids and tue.pk not in ids
        resp = client_for(worker.user).get("/api/v1/requests/")
        assert {r["id"] for r in data(resp)["results"]} == ids

    @pytest.mark.parametrize("reason", ["off_hours", "time_off", "busy"])
    def test_create_offer_refused(self, reason, worker, customer, make_request):
        day = next_weekday(MONDAY)
        if reason == "off_hours":
            set_hours(worker, TUESDAY)
        elif reason == "time_off":
            TimeOff.objects.create(worker=worker, start_date=day, end_date=day)
        else:
            accept_offer(offer(worker, make_request(customer, preferred_time=local(day, 10))), customer)
        req = make_request(customer, preferred_time=local(day, 11))
        with pytest.raises(BusinessRuleError) as exc:
            offer(worker, req)
        assert exc.value.get_codes() == f"worker_{reason}"
        assert exc.value.status_code == 409

    def test_create_offer_api_error_code(self, worker, customer, make_request):
        set_hours(worker, TUESDAY)
        req = make_request(customer, preferred_time=local(next_weekday(MONDAY), 10))
        resp = client_for(worker.user).post(f"/api/v1/requests/{req.pk}/offers/",
                                            {"price": "1000", "estimated_arrival_minutes": 30}, format="json")
        # The worker cannot even see this request, so it is hidden or refused.
        assert resp.status_code in (404, 409)

    def test_accept_refuses_double_booking(self, worker, customer, make_customer, make_request):
        day = next_weekday(MONDAY)
        other = make_customer()
        r1 = make_request(customer, preferred_time=local(day, 10))
        r2 = make_request(other, preferred_time=local(day, 11))
        o1, o2 = offer(worker, r1), offer(worker, r2)  # both offered before either was accepted
        accept_offer(o1, customer)
        with pytest.raises(ConflictError):
            accept_offer(o2, other)

    def test_back_to_back_bookings_allowed(self, worker, customer, make_request):
        day = next_weekday(MONDAY)
        accept_offer(offer(worker, make_request(customer, preferred_time=local(day, 10))), customer)
        accept_offer(offer(worker, make_request(customer, preferred_time=local(day, 12))), customer)


@pytest.mark.django_db
class TestSlots:
    def test_counts_free_workers_per_slot(self, make_worker, customer, category, make_request):
        a = make_worker(name="A")
        b = make_worker(name="B")
        set_hours(b, MONDAY, start=time(8), end=time(12))
        day = next_weekday(MONDAY)
        accept_offer(offer(a, make_request(customer, preferred_time=local(day, 14))), customer)
        resp = client_for(customer).get(SLOTS, {"category": category.pk, "latitude": str(LAHORE[0]),
                                                "longitude": str(LAHORE[1]), "date": day.isoformat()})
        assert resp.status_code == 200, resp.json()
        slots = {timezone.localtime(datetime.fromisoformat(s["start"])).hour: s["free_workers"] for s in data(resp)}
        assert sorted(slots) == [8, 10, 12, 14, 16, 18]
        assert slots[8] == 2 and slots[10] == 2 and slots[12] == 1 and slots[14] == 0 and slots[16] == 1
        # Counts only: no worker identity leaks.
        assert set(data(resp)[0]) == {"start", "end", "free_workers"}

    def test_past_slots_are_skipped_today(self, worker, customer, category):
        resp = client_for(customer).get(SLOTS, {"category": category.pk, "latitude": str(LAHORE[0]),
                                                "longitude": str(LAHORE[1]), "date": timezone.localdate().isoformat()})
        assert resp.status_code == 200
        soon = timezone.now() + timedelta(minutes=30)
        assert all(datetime.fromisoformat(s["start"]) >= soon for s in data(resp))

    def test_validation(self, customer, category, api):
        c = client_for(customer)
        base = {"category": category.pk, "latitude": "31.5", "longitude": "74.3"}
        assert c.get(SLOTS, {**base, "date": (timezone.localdate() - timedelta(days=1)).isoformat()}).status_code == 400
        assert c.get(SLOTS, {**base, "date": (timezone.localdate() + timedelta(days=90)).isoformat()}).status_code == 400
        assert c.get(SLOTS, base).status_code == 400
        assert api.get(SLOTS, {**base, "date": timezone.localdate().isoformat()}).status_code == 401


@pytest.mark.django_db
class TestScheduleApi:
    def test_get_and_replace_hours(self, worker):
        c = client_for(worker.user)
        assert data(c.get(SCHEDULE)) == {"hours": [], "time_off": []}
        body = {"hours": [{"weekday": 0, "start": "09:00", "end": "17:00"},
                          {"weekday": 5, "start": "10:00", "end": "14:00"}]}
        resp = c.put(SCHEDULE, body, format="json")
        assert resp.status_code == 200, resp.json()
        assert data(resp)["hours"] == body["hours"]
        resp = c.put(SCHEDULE, {"hours": [{"weekday": 2, "start": "08:00", "end": "12:00"}]}, format="json")
        assert [h["weekday"] for h in data(resp)["hours"]] == [2]
        assert WorkingHours.objects.filter(worker=worker).count() == 1
        # Clearing hours means "any time".
        assert data(c.put(SCHEDULE, {"hours": []}, format="json"))["hours"] == []

    @pytest.mark.parametrize("hours", [
        [{"weekday": 0, "start": "17:00", "end": "09:00"}],
        [{"weekday": 0, "start": "09:00", "end": "12:00"}, {"weekday": 0, "start": "13:00", "end": "17:00"}],
        [{"weekday": 7, "start": "09:00", "end": "12:00"}],
    ])
    def test_invalid_hours(self, worker, hours):
        resp = client_for(worker.user).put(SCHEDULE, {"hours": hours}, format="json")
        assert resp.status_code == 400
        assert not WorkingHours.objects.filter(worker=worker).exists()

    def test_time_off_add_and_delete(self, worker, make_worker):
        c = client_for(worker.user)
        start = timezone.localdate() + timedelta(days=3)
        resp = c.post(TIME_OFF, {"start_date": start.isoformat(), "end_date": (start + timedelta(days=1)).isoformat(),
                                 "reason": "Wedding"}, format="json")
        assert resp.status_code == 201, resp.json()
        pk = data(resp)["id"]
        assert [o["id"] for o in data(c.get(SCHEDULE))["time_off"]] == [pk]
        # Another worker cannot delete it.
        assert client_for(make_worker().user).delete(f"{TIME_OFF}{pk}/").status_code == 404
        assert c.delete(f"{TIME_OFF}{pk}/").status_code == 204
        assert not TimeOff.objects.exists()

    def test_time_off_validation(self, worker):
        c = client_for(worker.user)
        today = timezone.localdate()
        bad = [
            {"start_date": today.isoformat(), "end_date": (today - timedelta(days=1)).isoformat()},
            {"start_date": (today - timedelta(days=5)).isoformat(), "end_date": (today - timedelta(days=2)).isoformat()},
            {"start_date": today.isoformat(), "end_date": (today + timedelta(days=120)).isoformat()},
        ]
        for body in bad:
            assert c.post(TIME_OFF, body, format="json").status_code == 400

    def test_customers_cannot_use_worker_schedule(self, customer):
        c = client_for(customer)
        assert c.get(SCHEDULE).status_code == 403
        assert c.post(TIME_OFF, {}, format="json").status_code == 403

    def test_public_profile_shows_hours_but_not_time_off(self, worker, customer):
        set_hours(worker, MONDAY)
        TimeOff.objects.create(worker=worker, start_date=timezone.localdate(), end_date=timezone.localdate(),
                               reason="Private family matter")
        body = data(client_for(customer).get(f"/api/v1/workers/{worker.pk}/"))
        assert body["working_hours"] == [{"weekday": 0, "start": "09:00", "end": "17:00"}]
        assert "Private family matter" not in str(body)


@pytest.mark.django_db
def test_request_duration_field(customer, category):
    c = client_for(customer)
    resp = c.post("/api/v1/requests/", request_payload(category, duration_minutes=240), format="json")
    assert resp.status_code == 201, resp.json()
    assert data(resp)["duration_minutes"] == 240
    assert c.post("/api/v1/requests/", request_payload(category, duration_minutes=10), format="json").status_code == 400
    assert c.post("/api/v1/requests/", request_payload(category, duration_minutes=600), format="json").status_code == 400
    assert data(c.post("/api/v1/requests/", request_payload(category), format="json"))["duration_minutes"] == 120
