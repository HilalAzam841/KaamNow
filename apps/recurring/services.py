"""Recurring jobs: a job that repeats with the same worker.

A Celery task runs every 15 minutes. For each active plan whose next visit is less than two days
away it creates the visit's request: a book-again request for the usual worker when they can take
it, otherwise a normal request for every free worker nearby. Then the plan moves to the next date.
Each visit has a unique row, so a visit is never created twice.
"""

import calendar
import logging
from datetime import timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import RecurringJob, RecurringVisit

logger = logging.getLogger(__name__)
LEAD = timedelta(days=2)
MAX_ACTIVE_PER_CUSTOMER = 20


def add_period(when, frequency):
    """The next visit after `when`, keeping the local time of day (and day of month, capped)."""
    if frequency == RecurringJob.Frequency.WEEKLY:
        return when + timedelta(days=7)
    if frequency == RecurringJob.Frequency.BIWEEKLY:
        return when + timedelta(days=14)
    local = timezone.localtime(when)
    year, month = (local.year + 1, 1) if local.month == 12 else (local.year, local.month + 1)
    day = min(local.day, calendar.monthrange(year, month)[1])
    return local.replace(year=year, month=month, day=day)


def _check_owner(plan, user):
    if plan.customer_id != user.pk:
        raise BusinessRuleError(_("Only the customer can change this repeating job."),
                                status_code=http_status.HTTP_403_FORBIDDEN)


@transaction.atomic
def create_from_booking(booking, user, *, frequency, first_visit):
    """Repeat a booked or finished job with the same worker."""
    from apps.jobs.models import Booking

    if booking.customer_id != user.pk:
        raise BusinessRuleError(_("Only the customer can repeat this job."), status_code=http_status.HTTP_403_FORBIDDEN)
    if booking.status == Booking.Status.CANCELLED:
        raise BusinessRuleError(_("A cancelled job cannot be repeated."), status_code=http_status.HTTP_409_CONFLICT)
    if RecurringJob.objects.filter(customer=user, status__in=[RecurringJob.Status.ACTIVE, RecurringJob.Status.PAUSED],
                                   source_booking=booking).exists():
        raise BusinessRuleError(_("This job already repeats."), status_code=http_status.HTTP_409_CONFLICT)
    if RecurringJob.objects.filter(customer=user, status=RecurringJob.Status.ACTIVE).count() >= MAX_ACTIVE_PER_CUSTOMER:
        raise BusinessRuleError(_("You can have up to 20 repeating jobs. Cancel one first."))
    if first_visit <= timezone.now() + timedelta(hours=2):
        raise BusinessRuleError(_("The first visit must be at least two hours from now."))
    req = booking.request
    plan = RecurringJob.objects.create(
        customer=user, worker=booking.worker, category=req.category, title=req.title, description=req.description,
        latitude=req.latitude, longitude=req.longitude, address=req.address, area=req.area,
        duration_minutes=req.duration_minutes, budget=req.budget, frequency=frequency, next_visit=first_visit,
        source_booking=booking,
    )
    worker_user = booking.worker.user
    transaction.on_commit(lambda: notify(
        worker_user, Notification.Type.RECURRING,
        t("{name} wants you every time", name=user.full_name.split(" ")[0]),
        t("\"{title}\" now repeats. You will get each visit as a book-again job two days before.", title=req.title),
        {"recurring_id": plan.pk}))
    return plan


def pause(plan, user):
    _check_owner(plan, user)
    if plan.status != RecurringJob.Status.ACTIVE:
        raise BusinessRuleError(_("Only an active repeating job can be paused."), status_code=http_status.HTTP_409_CONFLICT)
    plan.status = RecurringJob.Status.PAUSED
    plan.save(update_fields=["status", "updated_at"])
    return plan


def resume(plan, user):
    _check_owner(plan, user)
    if plan.status != RecurringJob.Status.PAUSED:
        raise BusinessRuleError(_("Only a paused repeating job can be resumed."), status_code=http_status.HTTP_409_CONFLICT)
    # Visits missed while paused are skipped, not created late.
    soonest = timezone.now() + timedelta(hours=2)
    while plan.next_visit < soonest:
        plan.next_visit = add_period(plan.next_visit, plan.frequency)
    plan.status = RecurringJob.Status.ACTIVE
    plan.save(update_fields=["status", "next_visit", "updated_at"])
    return plan


def cancel(plan, user):
    _check_owner(plan, user)
    if plan.status == RecurringJob.Status.CANCELLED:
        raise BusinessRuleError(_("This repeating job is already cancelled."), status_code=http_status.HTTP_409_CONFLICT)
    plan.status = RecurringJob.Status.CANCELLED
    plan.save(update_fields=["status", "updated_at"])
    return plan


def skip_next(plan, user):
    _check_owner(plan, user)
    if plan.status != RecurringJob.Status.ACTIVE:
        raise BusinessRuleError(_("Only an active repeating job can skip a visit."), status_code=http_status.HTTP_409_CONFLICT)
    plan.next_visit = add_period(plan.next_visit, plan.frequency)
    plan.save(update_fields=["next_visit", "updated_at"])
    return plan


def leave(plan, worker):
    """The worker stops doing this job. Future visits go to every free worker nearby."""
    if plan.worker_id != worker.pk:
        raise BusinessRuleError(_("This repeating job is not yours."), status_code=http_status.HTTP_403_FORBIDDEN)
    plan.worker = None
    plan.save(update_fields=["worker", "updated_at"])
    notify(plan.customer, Notification.Type.RECURRING,
           t("{name} stopped your repeating job", name=worker.user.full_name.split(" ")[0]),
           t("Future visits of \"{title}\" will go to every free worker nearby.", title=plan.title),
           {"recurring_id": plan.pk})
    return plan


def _create_visit(plan):
    from apps.jobs.services import create_service_request

    when = plan.next_visit
    try:
        with transaction.atomic():
            visit = RecurringVisit.objects.create(plan=plan, scheduled_for=when, outcome=RecurringVisit.Outcome.FAILED)
    except IntegrityError:
        return None  # already created by another run
    fields = dict(category=plan.category, title=plan.title, description=plan.description, latitude=plan.latitude,
                  longitude=plan.longitude, address=plan.address, area=plan.area, preferred_time=when,
                  duration_minutes=plan.duration_minutes, budget=plan.budget, is_emergency=False)
    request, outcome, note = None, RecurringVisit.Outcome.FAILED, ""
    if plan.worker is not None:
        try:
            with transaction.atomic():  # a refusal rolls the half-made request back
                request = create_service_request(plan.customer, invited_worker=plan.worker, **fields)
            outcome = RecurringVisit.Outcome.SENT_TO_WORKER
        except BusinessRuleError as exc:
            note = str(exc.detail)[:255]
    if request is None:
        try:
            with transaction.atomic():
                request = create_service_request(plan.customer, **fields)
            outcome = RecurringVisit.Outcome.SENT_TO_ALL
        except BusinessRuleError as exc:
            note = str(exc.detail)[:255]
    visit.request, visit.outcome, visit.note = request, outcome, note
    visit.save(update_fields=["request", "outcome", "note"])
    if outcome == RecurringVisit.Outcome.SENT_TO_ALL and plan.worker is not None:
        notify(plan.customer, Notification.Type.RECURRING, t("Your usual worker is not free"),
               t("{name} cannot come for \"{title}\" then, so we sent it to other workers nearby.",
                 name=plan.worker.user.full_name.split(" ")[0], title=plan.title),
               {"request_id": request.pk, "recurring_id": plan.pk})
    elif outcome == RecurringVisit.Outcome.FAILED:
        notify(plan.customer, Notification.Type.RECURRING, t("A repeating job could not be posted"),
               t("\"{title}\": {reason}", title=plan.title, reason=note), {"recurring_id": plan.pk})
    return visit


def create_due_visits(now=None):
    """Creates the requests for visits starting within two days. Returns how many were created."""
    now = now or timezone.now()
    count = 0
    plans = RecurringJob.objects.filter(status=RecurringJob.Status.ACTIVE, next_visit__lte=now + LEAD).select_related(
        "customer", "worker__user", "category")
    for plan in plans:
        with transaction.atomic():
            plan = RecurringJob.objects.select_for_update(of=("self",)).select_related(
                "customer", "worker__user", "category").get(pk=plan.pk)
            if plan.status != RecurringJob.Status.ACTIVE or plan.next_visit > now + LEAD:
                continue
            if plan.next_visit > now + timedelta(minutes=5):
                count += _create_visit(plan) is not None
            # Move on (a visit already in the past, e.g. after downtime, is skipped).
            while plan.next_visit <= now + LEAD:
                plan.next_visit = add_period(plan.next_visit, plan.frequency)
            plan.save(update_fields=["next_visit", "updated_at"])
    return count


def update(plan, user, data):
    _check_owner(plan, user)
    if plan.status == RecurringJob.Status.CANCELLED:
        raise BusinessRuleError(_("This repeating job is cancelled."), status_code=http_status.HTTP_409_CONFLICT)
    fields = []
    for key in ("frequency", "next_visit", "budget"):
        if key in data:
            setattr(plan, key, data[key])
            fields.append(key)
    if fields:
        plan.save(update_fields=[*fields, "updated_at"])
    return plan
