"""Parts and materials on a booking.

- The booking's worker adds a part (name, quantity, unit price, optional receipt photo) once they
  have arrived, and until the customer starts paying. At most MAX_PARTS per booking and
  MAX_PARTS_TOTAL in all.
- The customer approves or rejects each part (with a reason). Only approved parts are added to
  Booking.parts_amount, which is part of Booking.total_amount. A payment cannot start while a
  part is waiting for the customer.
- KaamNow takes no commission on parts: commission stays on the agreed price. When the customer
  pays online, the parts money is owed to the worker (a wallet adjustment); in cash the worker
  already holds it.
- The worker can remove a part that is still waiting.
"""

from decimal import Decimal

from django.db import transaction
from django.db.models import F, Sum
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import money, t
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import MAX_PARTS, MAX_PARTS_TOTAL, JobPart

ADD_STATUSES = (Booking.Status.ARRIVED, Booking.Status.IN_PROGRESS, Booking.Status.COMPLETED)
ZERO = Decimal("0.00")


def _conflict(message, code):
    return BusinessRuleError(message, code=code, status_code=http_status.HTTP_409_CONFLICT)


def payment_started(booking):
    from apps.billing.models import Payment

    return Payment.objects.filter(
        booking=booking, purpose=Payment.Purpose.BOOKING,
        status__in=[Payment.Status.PENDING, Payment.Status.COMPLETED]).exists()


def open_for_changes(booking):
    return booking.status in ADD_STATUSES and not payment_started(booking)


def summary(booking, user=None):
    parts = list(booking.parts.all())
    is_worker = user is not None and user.pk == booking.worker.user_id
    is_customer = user is not None and user.pk == booking.customer_id
    open_ = booking.status in ADD_STATUSES and (is_worker or is_customer) and not payment_started(booking)
    return {
        "approved_total": booking.parts_amount,
        "pending": sum(1 for p in parts if p.status == JobPart.Status.PENDING),
        "count": len(parts),
        "can_add": is_worker and open_ and len(parts) < MAX_PARTS,
        "can_decide": is_customer and open_,
    }


def _recalculate(booking):
    total = JobPart.objects.filter(booking=booking, status=JobPart.Status.APPROVED).aggregate(
        s=Sum(F("unit_price") * F("quantity")))["s"] or ZERO
    Booking.objects.filter(pk=booking.pk).update(parts_amount=total)
    booking.parts_amount = total
    return total


def _locked_booking(booking):
    return Booking.objects.select_for_update().select_related("customer", "worker__user", "request").get(pk=booking.pk)


def add_part(booking, user, *, name, quantity, unit_price, receipt=None):
    from apps.portfolio.services import clean_image

    if user.pk != booking.worker.user_id:
        raise BusinessRuleError(_("Only the worker on this job can add parts."), status_code=403)
    picture = clean_image(receipt) if receipt else None
    with transaction.atomic():
        booking = _locked_booking(booking)
        if not open_for_changes(booking):
            raise _conflict(_("Add parts once you have arrived, before the customer pays."), "parts_closed")
        existing = JobPart.objects.filter(booking=booking).exclude(status=JobPart.Status.REJECTED)
        if JobPart.objects.filter(booking=booking).count() >= MAX_PARTS:
            raise _conflict(_("You can add up to %(n)d parts to a job.") % {"n": MAX_PARTS}, "parts_limit")
        running = sum((p.total for p in existing), ZERO) + unit_price * quantity
        if running > MAX_PARTS_TOTAL:
            raise _conflict(_("Parts for one job can total at most %(amount)s.") % {"amount": money(MAX_PARTS_TOTAL)},
                            "parts_total_limit")
        part = JobPart(booking=booking, name=name.strip(), quantity=quantity, unit_price=unit_price, added_by=user)
        if picture is not None:
            part.receipt.save(picture.name, picture, save=False)
        part.save()
        notify(booking.customer, Notification.Type.BOOKING_STATUS,
               t("Approve a part for \"{job}\"", job=booking.request.title),
               t("{name} added {part} for {amount}. Approve it before paying.",
                 name=user.full_name.split(" ")[0], part=part.name, amount=money(part.total)),
               {"booking_id": booking.pk, "part_id": part.pk})
    return part


def _decide(booking, user, part, approve, reason=""):
    with transaction.atomic():
        booking = _locked_booking(booking)
        if user.pk != booking.customer_id:
            raise BusinessRuleError(_("Only the customer can approve or reject parts."), status_code=403)
        part = JobPart.objects.select_for_update().get(pk=part.pk, booking=booking)
        if part.status != JobPart.Status.PENDING:
            raise _conflict(_("This part was already approved or rejected."), "part_decided")
        if not open_for_changes(booking):
            raise _conflict(_("Parts can no longer be changed for this job."), "parts_closed")
        part.status = JobPart.Status.APPROVED if approve else JobPart.Status.REJECTED
        part.reject_reason = "" if approve else reason.strip()
        part.decided_at = timezone.now()
        part.save(update_fields=["status", "reject_reason", "decided_at"])
        _recalculate(booking)
        title = t("Part approved") if approve else t("Part rejected")
        body = (t("The customer approved {part} ({amount}).", part=part.name, amount=money(part.total)) if approve
                else t("The customer rejected {part}: {reason}", part=part.name, reason=part.reject_reason))
        notify(booking.worker.user, Notification.Type.BOOKING_STATUS, title, body,
               {"booking_id": booking.pk, "part_id": part.pk})
    return part


def approve(booking, user, part):
    return _decide(booking, user, part, True)


def reject(booking, user, part, *, reason):
    if len((reason or "").strip()) < 3:
        raise BusinessRuleError(_("Tell the worker why in a few words."))
    return _decide(booking, user, part, False, reason)


def delete_part(booking, user, part):
    with transaction.atomic():
        booking = _locked_booking(booking)
        if user.pk != booking.worker.user_id:
            raise BusinessRuleError(_("Only the worker on this job can remove parts."), status_code=403)
        if part.status != JobPart.Status.PENDING or not open_for_changes(booking):
            raise _conflict(_("Only a part still waiting for the customer can be removed."), "part_locked")
        if part.receipt:
            part.receipt.delete(save=False)
        part.delete()


def require_no_pending(booking):
    """Called before a payment starts: every part must be approved or rejected first."""
    if JobPart.objects.filter(booking=booking, status=JobPart.Status.PENDING).exists():
        raise _conflict(_("Approve or reject the parts the worker added before paying."), "parts_pending")
