"""Worker earnings reports and CSV statements."""

import csv
import io
from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest

from apps.billing.models import Commission, Payment, WorkerAdjustment
from conftest import advance_to, client_for, data, jazzcash_callback

PAY = "/api/v1/payments/"
REPORT = "/api/v1/payments/earnings/report/"
STATEMENT = "/api/v1/payments/earnings/statement/"
PKT = ZoneInfo("Asia/Karachi")


def at(y, m, d, h=12):
    return datetime(y, m, d, h, tzinfo=PKT)


@pytest.fixture
def job(customer, worker, make_request, make_offer, api, gateways):
    """Completes a job for `worker` (paid by cash, online or not yet) and dates it `when`."""
    from apps.jobs.models import Booking
    from apps.jobs.services import confirm_completion_by_customer
    from apps.offers.services import accept_offer

    def _make(price, when, paid="cash", cat=None, title=None, who=None):
        w = who or worker
        req = make_request(customer, cat=cat)
        if title:
            req.title = title
            req.save(update_fields=["title"])
        booking = accept_offer(make_offer(w, req, price), customer)
        booking = confirm_completion_by_customer(advance_to(booking, Booking.Status.IN_PROGRESS), customer)
        if paid == "cash":
            p = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}))
            assert client_for(w.user).post(f"{PAY}{p['id']}/confirm/").status_code == 200
        elif paid == "online":
            body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash"}))
            payment = Payment.objects.get(pk=body["id"])
            assert api.post(f"{PAY}callbacks/jazzcash/", jazzcash_callback(payment), format="multipart").status_code == 200
        Commission.objects.filter(booking=booking).update(created_at=when)
        return booking

    return _make


def get(user, url, **params):
    return client_for(user).get(url, params)


@pytest.mark.django_db
class TestReport:
    def test_totals_series_services_payment_and_previous_period(self, worker, job, other_category):
        from apps.catalog.models import WorkerService

        WorkerService.objects.create(worker=worker, category=other_category)
        job("2000", at(2026, 11, 3), "cash")
        job("3000", at(2026, 11, 3, 18), "online")
        job("1000", at(2026, 11, 20), "none", cat=other_category)
        job("500", at(2026, 10, 15), "cash")  # the 30 days before
        job("700", at(2026, 12, 1), "cash")  # after the range

        r = data(get(worker.user, REPORT, start="2026-11-01", end="2026-11-30"))
        assert r["group"] == "day"
        assert r["totals"] == {"jobs": 3, "gross": "6000.00", "commission": "600.00", "discount": "0.00",
                               "earnings": "5400.00", "adjustments": "0.00", "net": "5400.00"}
        assert r["average_per_job"] == "1800.00"
        assert r["previous"]["start"] == "2026-10-02" and r["previous"]["end"] == "2026-10-31"
        assert r["previous"]["jobs"] == 1 and r["previous"]["net"] == "450.00"

        assert len(r["series"]) == 30, "every day is listed, with zeros on days without jobs"
        nov3 = r["series"][2]
        assert nov3 == {"start": "2026-11-03", "jobs": 2, "gross": "5000.00", "net": "4500.00"}
        assert r["series"][0]["jobs"] == 0 and r["series"][0]["net"] == "0.00"

        assert [(s["name"], s["jobs"], s["net"]) for s in r["by_service"]] == [
            ("Electrician", 2, "4500.00"), ("Plumber", 1, "900.00")]
        assert r["by_payment"]["cash"] == {"jobs": 1, "gross": "2000.00", "net": "1800.00"}
        assert r["by_payment"]["online"] == {"jobs": 1, "gross": "3000.00", "net": "2700.00"}
        assert r["by_payment"]["unpaid"] == {"jobs": 1, "gross": "1000.00", "net": "900.00"}

    def test_refund_shares_come_off_the_net(self, worker, job):
        job("2000", at(2026, 11, 3))
        WorkerAdjustment.objects.create(worker=worker, amount=Decimal("-300.00"), reason="Share of refund")
        WorkerAdjustment.objects.filter(worker=worker).update(created_at=at(2026, 11, 10))
        t = data(get(worker.user, REPORT, start="2026-11-01", end="2026-11-30"))["totals"]
        assert (t["earnings"], t["adjustments"], t["net"]) == ("1800.00", "-300.00", "1500.00")

    def test_days_follow_pakistan_time(self, worker, job):
        # 8 PM UTC on 30 November is 1 AM on 1 December in Lahore.
        job("2000", datetime(2026, 11, 30, 20, tzinfo=ZoneInfo("UTC")))
        nov = data(get(worker.user, REPORT, start="2026-11-01", end="2026-11-30"))
        dec = data(get(worker.user, REPORT, start="2026-12-01", end="2026-12-01"))
        assert nov["totals"]["jobs"] == 0
        assert dec["totals"]["jobs"] == 1 and dec["series"][0]["start"] == "2026-12-01"

    def test_weeks_and_months(self, worker, job):
        job("2000", at(2026, 11, 4))  # a Wednesday
        job("1000", at(2026, 12, 20))
        weeks = data(get(worker.user, REPORT, start="2026-11-01", end="2026-12-31"))
        assert weeks["group"] == "week"
        assert weeks["series"][0]["start"] == "2026-10-26", "weeks start on Monday"
        assert [b["jobs"] for b in weeks["series"] if b["jobs"]] == [1, 1]
        assert next(b for b in weeks["series"] if b["jobs"])["start"] == "2026-11-02"
        months = data(get(worker.user, REPORT, start="2026-01-01", end="2026-12-31"))
        assert months["group"] == "month" and len(months["series"]) == 12
        assert [b["net"] for b in months["series"][10:]] == ["1800.00", "900.00"]
        forced = data(get(worker.user, REPORT, start="2026-11-01", end="2026-12-31", group="month"))
        assert [b["start"] for b in forced["series"]] == ["2026-11-01", "2026-12-01"]

    def test_defaults_to_this_month(self, worker, job):
        from django.utils import timezone

        job("2000", timezone.now())
        r = data(get(worker.user, REPORT))
        today = timezone.localdate()
        assert r["start"] == today.replace(day=1).isoformat() and r["end"] == today.isoformat()
        assert r["totals"]["jobs"] == 1

    def test_only_your_own_earnings(self, worker, make_worker, job, customer):
        other = make_worker(name="Kamran Ali")
        job("2000", at(2026, 11, 3), who=other)
        assert data(get(worker.user, REPORT, start="2026-11-01", end="2026-11-30"))["totals"]["jobs"] == 0
        assert get(customer, REPORT).status_code == 403
        assert get(customer, STATEMENT).status_code == 403
        assert client_for(None).get(REPORT).status_code == 401

    @pytest.mark.parametrize("params", [
        {"start": "2026-11-30", "end": "2026-11-01"},
        {"start": "2025-01-01", "end": "2026-12-31"},
        {"start": "30/11/2026"},
        {"group": "year"},
    ])
    def test_bad_ranges_are_refused(self, worker, params):
        assert get(worker.user, REPORT, **params).status_code == 400
        if "group" not in params:
            assert get(worker.user, STATEMENT, **params).status_code == 400


@pytest.mark.django_db
class TestStatement:
    def test_csv_lists_jobs_and_refunds_without_customer_details(self, worker, job, customer):
        job("2000", at(2026, 11, 3), "cash")
        job("3000", at(2026, 11, 5), "online", title="=HYPERLINK(\"http://x\")")
        WorkerAdjustment.objects.create(worker=worker, amount=Decimal("-300.00"), reason="Share of refund")
        WorkerAdjustment.objects.filter(worker=worker).update(created_at=at(2026, 11, 4))
        job("900", at(2026, 12, 2))

        res = get(worker.user, STATEMENT, start="2026-11-01", end="2026-11-30")
        assert res.status_code == 200
        assert res["Content-Type"].startswith("text/csv")
        assert res["Content-Disposition"] == 'attachment; filename="kaamnow-earnings-2026-11-01-to-2026-11-30.csv"'
        assert "no-store" in res["Cache-Control"]
        body = res.content.decode("utf-8-sig")
        assert customer.phone not in body and customer.full_name not in body and "Gulberg" not in body
        rows = list(csv.reader(io.StringIO(body)))
        assert rows[0][0] == "Date" and rows[0][-1] == "Your earnings"
        assert [r[0] for r in rows[1:4]] == ["2026-11-03", "2026-11-04", "2026-11-05"], "oldest first"
        assert rows[1][2:] == ["Electrician", "Fan repair", "Cash", "2000.00", "0.00", "10.00", "200.00", "1800.00"]
        assert rows[2][3:5] == ["Share of refund", "Adjustment"] and rows[2][-1] == "-300.00"
        assert rows[3][3].startswith("'="), "a formula in a job title is not run by spreadsheet apps"
        assert rows[3][4] == "Online"
        assert rows[-1] == ["Total", "", "", "2 jobs", "", "5000.00", "0.00", "", "500.00", "4200.00"]

    def test_statement_in_urdu(self, worker, job):
        job("2000", at(2026, 11, 3))
        res = client_for(worker.user).get(STATEMENT, {"start": "2026-11-01", "end": "2026-11-30"},
                                          HTTP_ACCEPT_LANGUAGE="ur")
        header = next(csv.reader(io.StringIO(res.content.decode("utf-8-sig"))))
        assert header[0] == "تاریخ"
