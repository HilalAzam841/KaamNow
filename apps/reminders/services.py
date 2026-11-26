"""Booking reminders (the day before and an hour before) and no-show reports.

Reminders go to both the customer and the worker as an in-app alert and a push. The one-hour
reminder can also go by SMS when an admin switches that on. Each reminder is sent at most once per
booking (a unique row records it), so the task can run as often as it likes.
"""

import logging
from datetime import timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.common import sms
from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import category_name, t
from apps.notifications.models import Notification
from apps.notifications.services import notify, notify_many, render_for

from .models import BookingReminder, NoShowReport

logger = logging.getLogger(__name__)

DAY_BEFORE = timedelta(hours=24)
DAY_REMINDER_MIN_LEAD = timedelta(hours=3)  # closer than this, the hour reminder is enough
HOUR_BEFORE = timedelta(minutes=60)
JUST_BOOKED = timedelta(minutes=30)  # nobody needs a reminder for a job they booked a moment ago


def _when_text(start):
    local = timezone.localtime(start)
    clock = local.strftime("%H:%M")
    today = timezone.localdate()
    if local.date() == today:
        return t("today at {time}", time=clock)
    if local.date() == today + timedelta(days=1):
        return t("tomorrow at {time}", time=clock)
    return t("on {date} at {time}", date=local.strftime("%d/%m"), time=clock)


def _due(kind, now):
    """Confirmed, non-emergency bookings whose reminder of this kind is due and not yet sent."""
    from apps.jobs.models import Booking

    lead = DAY_BEFORE if kind == BookingReminder.Kind.DAY else HOUR_BEFORE
    qs = Booking.objects.filter(
        status=Booking.Status.CONFIRMED,
        request__is_emergency=False,
        request__preferred_time__gt=now,
        request__preferred_time__lte=now + lead,
        created_at__lte=now - JUST_BOOKED,
    ).exclude(reminders__kind=kind).select_related("request__category", "customer", "worker__user")
    if kind == BookingReminder.Kind.DAY:
        qs = qs.filter(request__preferred_time__gte=now + DAY_REMINDER_MIN_LEAD)
    return list(qs)


def _send_one(booking, kind, sms_on):
    try:
        with transaction.atomic():
            reminder = BookingReminder.objects.create(booking=booking, kind=kind)
    except IntegrityError:
        return False  # sent by another run
    start = booking.request.preferred_time
    cat = category_name(booking.request.category)
    when = _when_text(start)
    data = {"booking_id": booking.pk, "reminder": kind}
    customer, worker_user = booking.customer, booking.worker.user
    if kind == BookingReminder.Kind.DAY:
        c_title = w_title = t("Reminder: {category} job {when}", category=cat, when=when)
    else:
        c_title = w_title = t("Your {category} job starts {when}", category=cat, when=when)
    c_body = t("{name} is coming to {address}.", name=worker_user.full_name, address=booking.request.address)
    w_body = t("Job: {title}. Area: {area}. Open the booking for the address.", title=booking.request.title,
               area=booking.request.area or "-")
    recipients = [(u, title, body) for u, title, body in ((customer, c_title, c_body), (worker_user, w_title, w_body))
                  if u.booking_reminders]
    for user, title, body in recipients:
        notify(user, Notification.Type.REMINDER, title, body, data)
    if sms_on and kind == BookingReminder.Kind.HOUR:
        sent = False
        for user, title, _body in recipients:
            (text,) = render_for(user, t("KaamNow: {title}", title=title))
            try:
                sms.send(user.phone, text)
                sent = True
            except sms.SmsError:
                logger.warning("Reminder SMS for booking %s could not be sent", booking.pk)
        if sent:
            reminder.sms_sent = True
            reminder.save(update_fields=["sms_sent"])
    return True


def send_due_reminders(now=None):
    """Sends every reminder that is due. Returns how many bookings were reminded."""
    from apps.billing.models import PlatformSettings

    now = now or timezone.now()
    sms_on = PlatformSettings.load().reminder_sms_enabled and sms.is_available()
    count = 0
    for kind in (BookingReminder.Kind.HOUR, BookingReminder.Kind.DAY):
        for booking in _due(kind, now):
            # A job inside the hour gets only the hour reminder, never a late "day before" one.
            if kind == BookingReminder.Kind.DAY and booking.reminders.filter(kind=BookingReminder.Kind.HOUR).exists():
                continue
            count += _send_one(booking, kind, sms_on)
    return count


# ---------------------------------------------------------------------------------------------
# No-shows
# ---------------------------------------------------------------------------------------------
def grace_period():
    from apps.billing.models import PlatformSettings

    return timedelta(minutes=PlatformSettings.load().no_show_grace_minutes)


def no_show_side_for(booking, user, grace=None):
    """'worker' when this customer may report the worker absent, 'customer' when this worker may
    report the customer absent, else None. Also returns when reporting opens."""
    from apps.jobs.models import Booking

    grace = grace if grace is not None else grace_period()
    start = booking.request.preferred_time
    if user.pk == booking.customer_id and booking.status in (Booking.Status.CONFIRMED, Booking.Status.ON_THE_WAY):
        return NoShowReport.Side.WORKER, start + grace
    if user.pk == booking.worker.user_id and booking.status == Booking.Status.ARRIVED:
        return NoShowReport.Side.CUSTOMER, max(start, booking.arrived_at or start) + grace
    return None, None


@transaction.atomic
def report_no_show(booking, user, note=""):
    from apps.jobs.models import Booking
    from apps.jobs.services import cancel_booking

    booking = Booking.objects.select_for_update(of=("self",)).select_related(
        "request__category", "customer", "worker__user").get(pk=booking.pk)
    if NoShowReport.objects.filter(booking=booking).exists():
        raise BusinessRuleError(_("A no-show was already reported for this booking."),
                                status_code=http_status.HTTP_409_CONFLICT)
    side, opens_at = no_show_side_for(booking, user)
    if side is None:
        raise BusinessRuleError(_("You cannot report a no-show for this booking now."),
                                status_code=http_status.HTTP_409_CONFLICT)
    if timezone.now() < opens_at:
        raise BusinessRuleError(
            _("Please wait until {time} before reporting a no-show.").format(
                time=timezone.localtime(opens_at).strftime("%H:%M")),
            code="too_early", status_code=http_status.HTTP_409_CONFLICT,
        )
    if side == NoShowReport.Side.WORKER:
        against, reason = booking.worker.user, "No-show: the worker did not come."
    else:
        against, reason = booking.customer, "No-show: the customer was not there."
    report = NoShowReport.objects.create(booking=booking, side=side, reported_by=user, against=against,
                                         note=note.strip())
    cancel_booking(booking, user, reason)

    from apps.accounts.models import User

    admins = list(User.objects.filter(is_staff=True, is_active=True))
    if admins:
        notify_many(admins, Notification.Type.NO_SHOW, t("No-show reported"),
                    t("Booking #{id}: {who}", id=booking.pk, who=report.get_side_display()),
                    {"booking_id": booking.pk, "no_show_id": report.pk})
    notify(against, Notification.Type.NO_SHOW, t("You were reported as a no-show"),
           t("Booking #{id} was cancelled. If this is wrong, contact support from Help.", id=booking.pk),
           {"booking_id": booking.pk})
    return report


def no_show_counts(user_ids):
    """Confirmed or unreviewed no-shows per user (dismissed reports do not count)."""
    from django.db.models import Count

    rows = (NoShowReport.objects.filter(against_id__in=user_ids).exclude(review=NoShowReport.Review.DISMISSED)
            .values("against_id").annotate(n=Count("id")))
    return {r["against_id"]: r["n"] for r in rows}


def review_no_show(report, admin_user, *, review, note=""):
    report.review = review
    report.admin_note = note
    report.reviewed_by = admin_user
    report.reviewed_at = timezone.now()
    report.save(update_fields=["review", "admin_note", "reviewed_by", "reviewed_at"])
    if report.side == NoShowReport.Side.WORKER:
        from apps.levels.services import refresh as refresh_level

        refresh_level(report.booking.worker_id)
    return report
