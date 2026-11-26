"""Worker earnings reports: totals for a date range, a day/week/month series, a split by
service and by how the customer paid, and a CSV statement.

Dates are Pakistan dates (``settings.TIME_ZONE``). A job counts on the day it was completed
(when its commission was recorded). Refund shares charged to the worker count on the day
they were charged.
"""

import csv
import io
from datetime import date, datetime, time, timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDay, TruncMonth, TruncWeek
from django.utils import timezone
from django.utils.translation import get_language
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError

from .models import Commission, Payment, WorkerAdjustment

ZERO = Decimal("0.00")
MAX_DAYS = 366
GROUPS = ("day", "week", "month")
ONLINE = tuple(Payment.ONLINE_METHODS)


def default_range(today=None):
    """This month so far."""
    today = today or timezone.localdate()
    return today.replace(day=1), today


def auto_group(start, end):
    days = (end - start).days + 1
    return "day" if days <= 31 else "week" if days <= 120 else "month"


def check_range(start, end):
    if start > end:
        raise BusinessRuleError(_("The start date must be on or before the end date."))
    if (end - start).days + 1 > MAX_DAYS:
        raise BusinessRuleError(_("Choose a range of at most {days} days.").format(days=MAX_DAYS))


def _bounds(start, end):
    tz = timezone.get_current_timezone()
    return (timezone.make_aware(datetime.combine(start, time.min), tz),
            timezone.make_aware(datetime.combine(end + timedelta(days=1), time.min), tz))


def _commissions(worker, start, end):
    lo, hi = _bounds(start, end)
    return Commission.objects.filter(worker=worker, created_at__gte=lo, created_at__lt=hi)


def _adjustments(worker, start, end):
    lo, hi = _bounds(start, end)
    return WorkerAdjustment.objects.filter(worker=worker, created_at__gte=lo, created_at__lt=hi)


def _totals(worker, start, end):
    agg = _commissions(worker, start, end).aggregate(
        jobs=Count("id"), gross=Sum("gross_amount"), commission=Sum("commission_amount"),
        discount=Sum("discount_amount"), net=Sum("worker_earning"),
    )
    adjustments = _adjustments(worker, start, end).aggregate(s=Sum("amount"))["s"] or ZERO
    net = agg["net"] or ZERO
    return {
        "jobs": agg["jobs"],
        "gross": agg["gross"] or ZERO,
        "commission": agg["commission"] or ZERO,
        "discount": agg["discount"] or ZERO,
        "earnings": net,
        "adjustments": adjustments,
        "net": net + adjustments,
    }


def _bucket_start(d, group):
    if group == "week":
        return d - timedelta(days=d.weekday())
    if group == "month":
        return d.replace(day=1)
    return d


def _next_bucket(d, group):
    if group == "week":
        return d + timedelta(days=7)
    if group == "month":
        return (d.replace(day=28) + timedelta(days=4)).replace(day=1)
    return d + timedelta(days=1)


def _series(worker, start, end, group):
    trunc = {"day": TruncDay, "week": TruncWeek, "month": TruncMonth}[group]
    tz = timezone.get_current_timezone()
    rows = (_commissions(worker, start, end).annotate(b=trunc("created_at", tzinfo=tz)).values("b")
            .annotate(jobs=Count("id"), gross=Sum("gross_amount"), net=Sum("worker_earning")))
    found = {}
    for r in rows:
        b = r["b"]
        key = b.date() if isinstance(b, datetime) else b
        found[key] = r
    out = []
    d = _bucket_start(start, group)
    while d <= end:
        r = found.get(d, {})
        out.append({"start": d, "jobs": r.get("jobs", 0), "gross": r.get("gross") or ZERO,
                    "net": r.get("net") or ZERO})
        d = _next_bucket(d, group)
    return out


def _by_service(worker, start, end):
    rows = (_commissions(worker, start, end)
            .values("booking__request__category", "booking__request__category__name",
                    "booking__request__category__name_ur")
            .annotate(jobs=Count("id"), gross=Sum("gross_amount"), net=Sum("worker_earning"))
            .order_by("-net", "booking__request__category__name"))
    urdu = (get_language() or "").startswith("ur")
    return [{
        "category": r["booking__request__category"],
        "name": (r["booking__request__category__name_ur"] if urdu else "") or r["booking__request__category__name"],
        "jobs": r["jobs"], "gross": r["gross"], "net": r["net"],
    } for r in rows]


def _by_payment(worker, start, end):
    qs = _commissions(worker, start, end)
    split = {
        "cash": Q(paid_via=Payment.Method.CASH),
        "online": Q(paid_via__in=ONLINE),
        "unpaid": Q(paid_via=""),
    }
    out = {}
    for key, cond in split.items():
        agg = qs.filter(cond).aggregate(jobs=Count("id"), gross=Sum("gross_amount"), net=Sum("worker_earning"))
        out[key] = {"jobs": agg["jobs"], "gross": agg["gross"] or ZERO, "net": agg["net"] or ZERO}
    return out


def report(worker, start, end, group=None):
    check_range(start, end)
    group = group or auto_group(start, end)
    days = (end - start).days + 1
    prev_end = start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=days - 1)
    totals = _totals(worker, start, end)
    jobs = totals["jobs"]
    return {
        "start": start,
        "end": end,
        "group": group,
        "totals": totals,
        "average_per_job": (totals["earnings"] / jobs).quantize(Decimal("0.01")) if jobs else ZERO,
        "previous": {"start": prev_start, "end": prev_end, **_totals(worker, prev_start, prev_end)},
        "series": _series(worker, start, end, group),
        "by_service": _by_service(worker, start, end),
        "by_payment": _by_payment(worker, start, end),
    }


def _safe(value):
    """Stops spreadsheet apps from running a cell as a formula."""
    s = str(value)
    return "'" + s if s[:1] in ("=", "+", "-", "@", "\t", "\r") else s


def statement_csv(worker, start, end):
    """One row per completed job and per refund share in the range, oldest first, then totals.
    Shows no customer details."""
    check_range(start, end)
    tz = timezone.get_current_timezone()
    buf = io.StringIO()
    buf.write("﻿")  # so Excel reads Urdu text correctly
    w = csv.writer(buf)
    w.writerow([_("Date"), _("Booking"), _("Service"), _("Job"), _("Paid by"), _("Job price"),
                _("Customer discount"), _("Commission %"), _("Commission"), _("Your earnings")])
    rows = []
    for c in (_commissions(worker, start, end)
              .select_related("booking__request__category").order_by("created_at")):
        req = c.booking.request
        paid = {"cash": _("Cash"), "": _("Not paid yet")}.get(c.paid_via, _("Online"))
        rows.append((c.created_at, [
            timezone.localtime(c.created_at, tz).date().isoformat(), c.booking_id, req.category.display_name,
            _safe(req.title), paid, c.gross_amount, c.discount_amount, c.rate_percent, c.commission_amount,
            c.worker_earning,
        ]))
    for a in _adjustments(worker, start, end).order_by("created_at"):
        rows.append((a.created_at, [
            timezone.localtime(a.created_at, tz).date().isoformat(), "", "", _safe(a.reason), _("Adjustment"),
            "", "", "", "", a.amount,
        ]))
    for _at, row in sorted(rows, key=lambda r: r[0]):
        w.writerow(row)
    t = _totals(worker, start, end)
    w.writerow([])
    w.writerow([_("Total"), "", "", _("{n} jobs").format(n=t["jobs"]), "", t["gross"], t["discount"], "",
                t["commission"], t["net"]])
    return buf.getvalue()


def parse_dates(params, today=None):
    """Reads ``start``/``end`` (YYYY-MM-DD) and ``group`` from query params, defaulting to this month."""
    start, end = default_range(today)
    try:
        if params.get("start"):
            start = date.fromisoformat(params["start"])
        if params.get("end"):
            end = date.fromisoformat(params["end"])
    except ValueError:
        raise BusinessRuleError(_("Dates must look like 2026-12-31.")) from None
    group = params.get("group") or None
    if group and group not in GROUPS:
        raise BusinessRuleError(_("Group by day, week or month."))
    return start, end, group
