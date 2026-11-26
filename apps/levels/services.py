"""Worker levels and badges, worked out from jobs done, ratings and reliability.

Levels (each needs everything the one below needs, and more):

- new: everyone starts here.
- rising: 3 jobs done; rating 4.0 or more once rated.
- trusted: 15 jobs; 4.3 or more from at least 5 reviews; at most 1 confirmed no-show and at most
  10% of bookings cancelled by the worker in the last 90 days.
- top_rated: 50 jobs; 4.7 or more from at least 20 reviews; no confirmed no-show and at most 5%
  cancelled by the worker in the last 90 days.

Only verified workers get a level above new. A level is stored on the worker so lists can sort
and filter by it, and refreshed when a job is completed, reviewed or cancelled by the worker, when a
no-show is confirmed, and every night.
"""

from datetime import timedelta
from decimal import Decimal

from django.db.models import Q
from django.utils import timezone
from django.utils.translation import gettext_noop

from apps.accounts.models import WorkerProfile
from apps.common.i18n import t
from apps.notifications.models import Notification
from apps.notifications.services import notify

WINDOW_DAYS = 90
NEW, RISING, TRUSTED, TOP = "new", "rising", "trusted", "top_rated"
ORDER = [NEW, RISING, TRUSTED, TOP]
RANK = {lvl: i for i, lvl in enumerate(ORDER)}

# Requirements per level. None = not checked at that level.
RULES = {
    RISING: {"jobs": 3, "rating": Decimal("4.0"), "reviews": 0, "no_shows": None, "cancel_rate": None},
    TRUSTED: {"jobs": 15, "rating": Decimal("4.3"), "reviews": 5, "no_shows": 1, "cancel_rate": Decimal("10")},
    TOP: {"jobs": 50, "rating": Decimal("4.7"), "reviews": 20, "no_shows": 0, "cancel_rate": Decimal("5")},
}

BADGES = ("verified", "jobs_100", "experienced", "customer_favourite", "always_on_time")


def stats(worker, now=None):
    from apps.favourites.models import FavouriteWorker
    from apps.jobs.models import Booking
    from apps.reminders.models import NoShowReport

    now = now or timezone.now()
    since = now - timedelta(days=WINDOW_DAYS)
    recent = Booking.objects.filter(worker=worker, created_at__gte=since)
    total = recent.count()
    cancelled = recent.filter(status=Booking.Status.CANCELLED, cancelled_by=worker.user_id).count()
    no_shows = NoShowReport.objects.filter(
        against=worker.user_id, side=NoShowReport.Side.WORKER, review=NoShowReport.Review.CONFIRMED,
        created_at__gte=since,
    ).count()
    recent_done = recent.filter(status=Booking.Status.COMPLETED).count()
    return {
        "jobs": worker.completed_jobs_count,
        "rating": worker.average_rating,
        "reviews": worker.rating_count,
        "no_shows": no_shows,
        "cancel_rate": (Decimal(cancelled * 100) / total).quantize(Decimal("0.1")) if total else Decimal("0.0"),
        "recent_jobs": recent_done,
        "saved_by": FavouriteWorker.objects.filter(worker=worker).count(),
    }


def requirements(level, s):
    """Each requirement of `level` with the worker's value and whether it is met."""
    rule = RULES[level]
    out = [{"key": "jobs", "target": rule["jobs"], "value": s["jobs"], "met": s["jobs"] >= rule["jobs"]}]
    rated = s["reviews"] > 0
    out.append({"key": "rating", "target": rule["rating"], "value": s["rating"],
                "met": (s["rating"] >= rule["rating"]) if (rated or rule["reviews"]) else True})
    if rule["reviews"]:
        out.append({"key": "reviews", "target": rule["reviews"], "value": s["reviews"],
                    "met": s["reviews"] >= rule["reviews"]})
    if rule["no_shows"] is not None:
        out.append({"key": "no_shows", "target": rule["no_shows"], "value": s["no_shows"],
                    "met": s["no_shows"] <= rule["no_shows"]})
    if rule["cancel_rate"] is not None:
        out.append({"key": "cancel_rate", "target": rule["cancel_rate"], "value": s["cancel_rate"],
                    "met": s["cancel_rate"] <= rule["cancel_rate"]})
    return out


def level_for(worker, s):
    if not worker.is_verified:
        return NEW
    level = NEW
    for lvl in (RISING, TRUSTED, TOP):
        if all(r["met"] for r in requirements(lvl, s)):
            level = lvl
        else:
            break
    return level


def badges_for(worker, s):
    out = []
    if worker.is_verified:
        out.append("verified")
    if s["jobs"] >= 100:
        out.append("jobs_100")
    if worker.experience_years >= 5:
        out.append("experienced")
    if s["saved_by"] >= 5:
        out.append("customer_favourite")
    if s["recent_jobs"] >= 10 and s["no_shows"] == 0:
        out.append("always_on_time")
    return out


LEVEL_NAMES = {
    RISING: gettext_noop("Rising"),
    TRUSTED: gettext_noop("Trusted"),
    TOP: gettext_noop("Top rated"),
}


def refresh(worker, notify_change=True):
    """Works the level and badges out again and stores them. Tells the worker when they move up."""
    worker = WorkerProfile.objects.select_related("user").get(pk=getattr(worker, "pk", worker))
    s = stats(worker)
    level = level_for(worker, s)
    badges = badges_for(worker, s)
    old = worker.level
    if level == old and badges == worker.badges:
        return worker
    worker.level, worker.level_rank, worker.badges = level, RANK[level], badges
    fields = ["level", "level_rank", "badges", "updated_at"]
    if level != old:
        worker.level_since = timezone.now()
        fields.append("level_since")
    worker.save(update_fields=fields)
    if notify_change and RANK[level] > RANK.get(old, 0):
        notify(worker.user, Notification.Type.LEVEL, t("You moved up a level"),
               t("You are now {level} on KaamNow. Customers see it on your offers and profile.",
                 level=t(LEVEL_NAMES[level])),
               {"level": level})
    return worker


def refresh_all():
    """Nightly: recent no-shows and cancellations drop out of the 90 days, so levels can change
    without any new event. Returns how many workers changed."""
    changed = 0
    qs = WorkerProfile.objects.filter(
        Q(verification_status=WorkerProfile.VerificationStatus.VERIFIED) | ~Q(level=NEW) | ~Q(badges=[])
    ).only("pk")
    for w in qs.iterator():
        before = WorkerProfile.objects.values_list("level", "badges").get(pk=w.pk)
        after = refresh(w.pk)
        if (after.level, after.badges) != tuple(before):
            changed += 1
    return changed


def progress(worker):
    """For the worker's own page: their level, badges, and what the next level needs."""
    worker = WorkerProfile.objects.select_related("user").get(pk=worker.pk)
    s = stats(worker)
    current = level_for(worker, s)
    nxt = ORDER[RANK[current] + 1] if current != TOP else None
    return {
        "level": current,
        "badges": badges_for(worker, s),
        "next_level": nxt,
        "requirements": requirements(nxt, s) if nxt else [],
        "verified": worker.is_verified,
        "window_days": WINDOW_DAYS,
        "stats": {k: s[k] for k in ("jobs", "rating", "reviews", "no_shows", "cancel_rate")},
    }
