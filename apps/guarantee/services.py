"""Work guarantee: a free fix when a problem comes back after a job.

- The booking's customer claims within PlatformSettings.guarantee_days of completion, once per
  booking, describing the problem.
- The worker has RESPOND_HOURS to accept (with a time to come back) or decline (with a reason).
- Accepted: the worker comes back, marks the redo done, and the customer confirms it is fixed.
- The customer can escalate to the KaamNow team when the worker declined, did not answer in time,
  or the redo did not fix it. That opens a complaint (category "guarantee") for admins.
- The customer can withdraw an open claim.
"""

from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.billing.models import PlatformSettings
from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import t
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import GuaranteeClaim

RESPOND_HOURS = 48
REDO_WITHIN_DAYS = 14

Status = GuaranteeClaim.Status


def _conflict(message, code):
    return BusinessRuleError(message, code=code, status_code=http_status.HTTP_409_CONFLICT)


def window_ends(booking, cfg=None):
    if booking.completed_at is None:
        return None
    cfg = cfg or PlatformSettings.load()
    return booking.completed_at + timedelta(days=cfg.guarantee_days)


def can_claim(booking, user, cfg=None):
    cfg = cfg or PlatformSettings.load()
    if not cfg.guarantee_enabled or user is None or user.pk != booking.customer_id:
        return False
    if booking.status != Booking.Status.COMPLETED or booking.completed_at is None:
        return False
    if GuaranteeClaim.objects.filter(booking=booking).exists():
        return False
    return timezone.now() <= window_ends(booking, cfg)


def can_escalate(claim, now=None):
    now = now or timezone.now()
    if claim.status in (Status.DECLINED, Status.REDO_DONE):
        return True
    if claim.status == Status.PENDING:
        return now > claim.respond_by
    if claim.status == Status.ACCEPTED:
        # The worker said they would come back but did not mark it done a day after the agreed time.
        return claim.redo_time is not None and now > claim.redo_time + timedelta(days=1)
    return False


def _notify_worker(claim, title, body):
    notify(claim.worker.user, Notification.Type.BOOKING_STATUS, title, body,
           {"booking_id": claim.booking_id, "guarantee_claim_id": claim.pk})


def _notify_customer(claim, title, body):
    notify(claim.customer, Notification.Type.BOOKING_STATUS, title, body,
           {"booking_id": claim.booking_id, "guarantee_claim_id": claim.pk})


def _lock(claim):
    return GuaranteeClaim.objects.select_for_update().select_related(
        "booking__request", "customer", "worker__user").get(pk=claim.pk)


@transaction.atomic
def make_claim(booking, customer, *, problem):
    cfg = PlatformSettings.load()
    booking = Booking.objects.select_for_update().select_related("request", "worker__user").get(pk=booking.pk)
    if customer.pk != booking.customer_id:
        raise BusinessRuleError(_("Only the customer can make a guarantee claim."), status_code=403)
    if not cfg.guarantee_enabled:
        raise _conflict(_("The work guarantee is turned off."), "guarantee_disabled")
    if booking.status != Booking.Status.COMPLETED or booking.completed_at is None:
        raise _conflict(_("You can claim the guarantee once the job is completed."), "guarantee_not_completed")
    if GuaranteeClaim.objects.filter(booking=booking).exists():
        raise _conflict(_("You already made a guarantee claim for this job."), "guarantee_already_claimed")
    if timezone.now() > window_ends(booking, cfg):
        raise _conflict(_("The guarantee for this job ended %(days)d days after it was completed.")
                        % {"days": cfg.guarantee_days}, "guarantee_expired")
    problem = (problem or "").strip()
    if len(problem) < 10:
        raise BusinessRuleError(_("Describe the problem in a few words (at least 10 characters)."))
    claim = GuaranteeClaim.objects.create(
        booking=booking, customer=customer, worker=booking.worker, problem=problem,
        respond_by=timezone.now() + timedelta(hours=RESPOND_HOURS),
    )
    _notify_worker(claim, t("Guarantee claim on \"{job}\"", job=booking.request.title),
                   t("{name} says the problem came back. Please answer within 48 hours.",
                     name=customer.full_name.split(" ")[0]))
    return claim


def _require_worker(claim, user):
    if user.pk != claim.worker.user_id:
        raise BusinessRuleError(_("Only the worker on this job can do this."), status_code=403)


def _require_customer(claim, user):
    if user.pk != claim.customer_id:
        raise BusinessRuleError(_("Only the customer can do this."), status_code=403)


@transaction.atomic
def accept(claim, user, *, redo_time, note=""):
    claim = _lock(claim)
    _require_worker(claim, user)
    if claim.status != Status.PENDING:
        raise _conflict(_("This claim has already been answered."), "guarantee_not_pending")
    now = timezone.now()
    if redo_time < now - timedelta(minutes=5) or redo_time > now + timedelta(days=REDO_WITHIN_DAYS):
        raise BusinessRuleError(_("Pick a time to come back within the next %(days)d days.")
                                % {"days": REDO_WITHIN_DAYS})
    claim.status, claim.redo_time, claim.worker_note, claim.accepted_at = Status.ACCEPTED, redo_time, note, now
    claim.save(update_fields=["status", "redo_time", "worker_note", "accepted_at", "updated_at"])
    _notify_customer(claim, t("{name} will fix it for free", name=user.full_name.split(" ")[0]),
                     t("Your guarantee claim was accepted. Open the booking to see when they will come."))
    return claim


@transaction.atomic
def decline(claim, user, *, reason):
    claim = _lock(claim)
    _require_worker(claim, user)
    if claim.status != Status.PENDING:
        raise _conflict(_("This claim has already been answered."), "guarantee_not_pending")
    reason = (reason or "").strip()
    if len(reason) < 10:
        raise BusinessRuleError(_("Explain why in a few words (at least 10 characters)."))
    claim.status, claim.worker_note = Status.DECLINED, reason
    claim.save(update_fields=["status", "worker_note", "updated_at"])
    _notify_customer(claim, t("Guarantee claim declined"),
                     t("The worker declined your claim. If you disagree, send it to the KaamNow team."))
    return claim


@transaction.atomic
def mark_redo_done(claim, user):
    claim = _lock(claim)
    _require_worker(claim, user)
    if claim.status != Status.ACCEPTED:
        raise _conflict(_("Accept the claim before marking the fix done."), "guarantee_not_accepted")
    claim.status, claim.redo_done_at = Status.REDO_DONE, timezone.now()
    claim.save(update_fields=["status", "redo_done_at", "updated_at"])
    _notify_customer(claim, t("Is it fixed now?"),
                     t("The worker says the problem is fixed. Please confirm, or send it to the KaamNow team."))
    return claim


@transaction.atomic
def confirm_fixed(claim, user):
    claim = _lock(claim)
    _require_customer(claim, user)
    if claim.status not in (Status.ACCEPTED, Status.REDO_DONE):
        raise _conflict(_("There is no fix to confirm on this claim."), "guarantee_nothing_to_confirm")
    claim.status, claim.closed_at = Status.FIXED, timezone.now()
    claim.save(update_fields=["status", "closed_at", "updated_at"])
    _notify_worker(claim, t("Guarantee claim closed"), t("The customer confirmed the problem is fixed. Thank you!"))
    return claim


@transaction.atomic
def withdraw(claim, user):
    claim = _lock(claim)
    _require_customer(claim, user)
    if not claim.is_open:
        raise _conflict(_("This claim is already closed."), "guarantee_closed")
    claim.status, claim.closed_at = Status.WITHDRAWN, timezone.now()
    claim.save(update_fields=["status", "closed_at", "updated_at"])
    _notify_worker(claim, t("Guarantee claim withdrawn"), t("The customer withdrew their guarantee claim."))
    return claim


@transaction.atomic
def escalate(claim, user, *, details=""):
    from apps.support.models import Complaint
    from apps.support.services import create_complaint

    claim = _lock(claim)
    _require_customer(claim, user)
    if not can_escalate(claim):
        if claim.status == Status.PENDING:
            raise _conflict(_("The worker has 48 hours to answer. You can send it to the KaamNow team after that."),
                            "guarantee_wait_for_worker")
        raise _conflict(_("This claim cannot be sent to the KaamNow team now."), "guarantee_cannot_escalate")
    description = claim.problem
    if claim.worker_note:
        description += "\n\n" + _("Worker's answer: %(note)s") % {"note": claim.worker_note}
    if (details or "").strip():
        description += "\n\n" + _("More from the customer: %(details)s") % {"details": details.strip()}
    complaint = create_complaint(
        user, category=Complaint.Category.GUARANTEE,
        subject=_("Guarantee claim on booking #%(id)d") % {"id": claim.booking_id},
        description=description[:3000], booking=claim.booking,
    )
    claim.status, claim.complaint, claim.closed_at = Status.ESCALATED, complaint, timezone.now()
    claim.save(update_fields=["status", "complaint", "closed_at", "updated_at"])
    _notify_worker(claim, t("Guarantee claim sent to KaamNow"),
                   t("The customer asked the KaamNow team to look at their claim. We may contact you."))
    return claim
