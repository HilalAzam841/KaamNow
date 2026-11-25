"""Is a worker free for a job window? And which time slots have free workers?

A window is free when:
- it falls inside the worker's working hours for that weekday (local time, Asia/Karachi),
  or the worker has not set any hours (then any time counts);
- it is not on a day the worker has marked as time off;
- it does not overlap another active booking of the worker.

Emergency requests skip the first two rules: a worker who switched on "available" is free now.
"""

from datetime import datetime, time, timedelta

from django.utils import timezone
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError

from .models import TimeOff, WorkingHours

SLOT_MINUTES = 120
DAY_START = time(8, 0)
DAY_END = time(20, 0)


class Schedule:
    """A worker's hours, time off and booked windows, loaded once and checked many times."""

    def __init__(self, worker, hours, time_off, busy):
        self.worker = worker
        self.hours = {h.weekday: h for h in hours}
        self.time_off = list(time_off)
        self.busy = list(busy)  # [(start, end, booking_id)]

    def reason_not_free(self, start, end, *, emergency=False, ignore_booking=None):
        """None when free, else a short code: off_hours, time_off or busy."""
        if not emergency:
            local_start, local_end = timezone.localtime(start), timezone.localtime(end)
            if self.hours:
                h = self.hours.get(local_start.weekday())
                if (h is None or local_start.date() != local_end.date() and local_end.time() != time(0)
                        or local_start.time() < h.start_time or local_end.time() > h.end_time):
                    return "off_hours"
            for off in self.time_off:
                if off.start_date <= local_start.date() <= off.end_date or off.start_date <= local_end.date() <= off.end_date:
                    return "time_off"
        for b_start, b_end, b_id in self.busy:
            if b_id != ignore_booking and b_start < end and start < b_end:
                return "busy"
        return None


def _active_statuses():
    from apps.jobs.models import Booking

    return list(Booking.ACTIVE_STATUSES)


def busy_windows(worker_ids, start, end):
    """Active bookings of these workers that may overlap [start, end), per worker."""
    from apps.jobs.models import Booking

    out = {wid: [] for wid in worker_ids}
    # Jobs last at most a day, so look back one day for bookings that started earlier.
    qs = Booking.objects.filter(
        worker_id__in=worker_ids, status__in=_active_statuses(),
        request__preferred_time__lt=end, request__preferred_time__gte=start - timedelta(days=1),
    ).select_related("request")
    for b in qs:
        b_start, b_end = b.request.window
        out[b.worker_id].append((b_start, b_end, b.pk))
    return out


def schedules_for(workers, start, end):
    workers = list(workers)
    ids = [w.pk for w in workers]
    hours, offs = {}, {}
    for h in WorkingHours.objects.filter(worker_id__in=ids):
        hours.setdefault(h.worker_id, []).append(h)
    local_start = timezone.localtime(start).date() - timedelta(days=1)
    local_end = timezone.localtime(end).date() + timedelta(days=1)
    for o in TimeOff.objects.filter(worker_id__in=ids, end_date__gte=local_start, start_date__lte=local_end):
        offs.setdefault(o.worker_id, []).append(o)
    busy = busy_windows(ids, start, end)
    return {w.pk: Schedule(w, hours.get(w.pk, []), offs.get(w.pk, []), busy.get(w.pk, [])) for w in workers}


def free_workers(workers, start, end, *, emergency=False):
    workers = list(workers)
    if not workers:
        return []
    schedules = schedules_for(workers, start, end)
    return [w for w in workers if schedules[w.pk].reason_not_free(start, end, emergency=emergency) is None]


def why_not_free(worker, service_request, *, ignore_booking=None):
    start, end = service_request.window
    if service_request.is_emergency:
        start, end = timezone.now(), timezone.now() + timedelta(minutes=service_request.duration_minutes)
    return schedules_for([worker], start, end)[worker.pk].reason_not_free(
        start, end, emergency=service_request.is_emergency, ignore_booking=ignore_booking
    )


MESSAGES = {
    "off_hours": lambda: _("This job is outside your working hours. Change your schedule to take it."),
    "time_off": lambda: _("You marked this day as time off."),
    "busy": lambda: _("You already have a booking at this time."),
}


def check_worker_free(worker, service_request):
    reason = why_not_free(worker, service_request)
    if reason:
        raise BusinessRuleError(MESSAGES[reason](), code=f"worker_{reason}", status_code=409)


def request_fits_worker(worker, service_request, schedule=None):
    start, end = service_request.window
    if service_request.is_emergency:
        return True
    schedule = schedule or schedules_for([worker], start, end)[worker.pk]
    return schedule.reason_not_free(start, end) is None


def day_slots(day):
    """The standard 2-hour slots of a day (local time)."""
    tz = timezone.get_current_timezone()
    slots = []
    cur = datetime.combine(day, DAY_START, tzinfo=tz)
    last = datetime.combine(day, DAY_END, tzinfo=tz)
    while cur + timedelta(minutes=SLOT_MINUTES) <= last:
        slots.append((cur, cur + timedelta(minutes=SLOT_MINUTES)))
        cur += timedelta(minutes=SLOT_MINUTES)
    return slots


def slots_with_free_workers(workers, day):
    """[(start, end, free_count)] for the day's slots that have not started yet (30 minutes' notice)."""
    soon = timezone.now() + timedelta(minutes=30)
    slots = [s for s in day_slots(day) if s[0] >= soon]
    if not slots:
        return []
    workers = list(workers)
    schedules = schedules_for(workers, slots[0][0], slots[-1][1]) if workers else {}
    return [
        (start, end, sum(1 for w in workers if schedules[w.pk].reason_not_free(start, end) is None))
        for start, end in slots
    ]


def worker_day_slots(worker, day):
    """[(start, end, is_free)] for one worker's slots on a day that have not started yet."""
    soon = timezone.now() + timedelta(minutes=30)
    slots = [s for s in day_slots(day) if s[0] >= soon]
    if not slots:
        return []
    schedule = schedules_for([worker], slots[0][0], slots[-1][1])[worker.pk]
    taking_jobs = worker.can_receive_jobs
    return [(start, end, taking_jobs and schedule.reason_not_free(start, end) is None) for start, end in slots]


def replace_hours(worker, rows):
    WorkingHours.objects.filter(worker=worker).delete()
    WorkingHours.objects.bulk_create([
        WorkingHours(worker=worker, weekday=r["weekday"], start_time=r["start_time"], end_time=r["end_time"])
        for r in rows
    ])


def upcoming_time_off(worker):
    return TimeOff.objects.filter(worker=worker, end_date__gte=timezone.localdate())
