"""Refunds and disputed payments (admin only; the views audit every action).

KaamNow does not push money back through the gateways' APIs: an admin sends the refund from the
JazzCash / Easypaisa merchant portal, a bank or in cash, then records it here with its reference.

- A **completed booking payment** can be refunded in full or in part (several partial refunds up to
  the amount). The payment stays completed (the job was done and paid) with ``refunded_amount`` set.
  Optionally the worker's share of the refund is charged to their wallet as a negative
  ``WorkerAdjustment``, settled with their next payout or commission payment.
- A **disputed payment** (money reported after the checkout closed, or an amount mismatch) is never
  settled automatically. An admin resolves it: *accept* (a booking payment counts as the booking's
  payment), *refund* (the money is returned; status ``refunded``) or *reject* (no money arrived after
  checking the merchant portal; status ``failed``).
"""

from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.common.i18n import money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import LedgerEntry, Payment, Refund, WorkerAdjustment

CENT = Decimal("0.01")
ZERO = Decimal("0.00")


def _locked(payment):
    return (
        Payment.objects.select_for_update(of=("self",))
        .select_related("booking__worker__user", "booking__commission", "payer")
        .get(pk=payment.pk)
    )


def refundable(payment):
    if payment.status != Payment.Status.COMPLETED or payment.purpose != Payment.Purpose.BOOKING:
        return ZERO
    return payment.amount - payment.refunded_amount


def _check_complaint(complaint, payment):
    if complaint is not None and payment.booking_id and complaint.booking_id not in (None, payment.booking_id):
        raise BusinessRuleError(_("This complaint is about a different booking."))


def _record(payment, admin_user, *, amount, worker_share, method, reason, reference, complaint):
    refund = Refund.objects.create(
        payment=payment, amount=amount, worker_share=worker_share, method=method, reason=reason.strip(),
        reference=reference.strip(), complaint=complaint, created_by=admin_user,
    )
    booking = payment.booking
    worker = booking.worker if booking else None
    LedgerEntry.objects.create(
        refund=refund, payment=payment, booking=booking, worker=worker, amount=amount,
        entry_type=LedgerEntry.EntryType.CUSTOMER_REFUND,
        description=f"Refund via {refund.get_method_display()}: {refund.reason}"[:255],
    )
    payment.refunded_amount += amount
    return refund


def _notify_customer(payment, refund):
    notify(payment.payer, Notification.Type.PAYMENT, t("Refund sent"),
           t("We refunded {amount} for payment {reference}. Refund reference: {refund_reference}.",
             amount=money(refund.amount), reference=payment.reference, refund_reference=refund.reference),
           {"payment_id": payment.pk, "booking_id": payment.booking_id, "refund_id": refund.pk})


@transaction.atomic
def refund_payment(payment, admin_user, *, amount, method, reason, reference, charge_worker=False, complaint=None):
    """Records a refund on a completed booking payment."""
    payment = _locked(payment)
    if payment.purpose != Payment.Purpose.BOOKING:
        raise BusinessRuleError(_("Only booking payments can be refunded here."))
    if payment.status != Payment.Status.COMPLETED:
        raise ConflictError(_("Only a completed payment can be refunded."))
    left = payment.amount - payment.refunded_amount
    if amount > left:
        raise BusinessRuleError(_("You can refund at most {amount}.").format(amount=money(left)))
    _check_complaint(complaint, payment)
    booking = payment.booking
    worker_share = ZERO
    if charge_worker:
        commission = getattr(booking, "commission", None)
        earning = commission.worker_earning if commission else ZERO
        gross = payment.amount + payment.discount_amount  # the booking total, before any promo discount
        worker_share = min(amount, (amount * earning / gross).quantize(CENT, ROUND_HALF_UP))
    refund = _record(payment, admin_user, amount=amount, worker_share=worker_share, method=method, reason=reason,
                     reference=reference, complaint=complaint)
    payment.save(update_fields=["refunded_amount", "updated_at"])
    if worker_share > 0:
        WorkerAdjustment.objects.create(
            worker=booking.worker, amount=-worker_share, refund=refund,
            reason=f"Share of refund on booking #{booking.pk}: {refund.reason}"[:255],
        )
        notify(booking.worker.user, Notification.Type.PAYMENT, t("Refund charged to your wallet"),
               t("The customer of booking #{id} was refunded {amount}. Your share, {share}, is taken from your wallet.",
                 id=booking.pk, amount=money(amount), share=money(worker_share)),
               {"booking_id": booking.pk, "refund_id": refund.pk})
    _notify_customer(payment, refund)
    return refund


RESOLUTIONS = ("accept", "refund", "reject")


def _release(payment):
    from .services import _release_discount

    _release_discount(payment)


@transaction.atomic
def resolve_disputed(payment, admin_user, *, resolution, note, method=None, reference="", complaint=None):
    """Settles a disputed payment after the admin has checked the merchant portal."""
    from .services import _complete_payment

    payment = _locked(payment)
    if payment.status != Payment.Status.DISPUTED:
        raise ConflictError(_("This payment is not disputed."))
    note = note.strip()
    if resolution == "accept":
        if payment.purpose != Payment.Purpose.BOOKING:
            raise BusinessRuleError(_("Only a booking payment can be accepted. Refund this one instead."))
        if Payment.objects.filter(booking=payment.booking_id, status__in=[Payment.Status.PENDING,
                                                                       Payment.Status.COMPLETED]).exists():
            raise ConflictError(_("This booking already has another payment. Refund this one instead."))
        payment.failure_reason = f"Accepted by admin: {note}"[:255]
        payment.save(update_fields=["failure_reason", "updated_at"])
        return _complete_payment(payment, confirmed_by=admin_user), None
    if resolution == "refund":
        if not method or not reference.strip():
            raise BusinessRuleError(_("Give the refund method and its reference."))
        _check_complaint(complaint, payment)
        refund = _record(payment, admin_user, amount=payment.amount, worker_share=ZERO, method=method, reason=note,
                         reference=reference, complaint=complaint)
        payment.status = Payment.Status.REFUNDED
        payment.save(update_fields=["status", "refunded_amount", "updated_at"])
        _release(payment)
        _notify_customer(payment, refund)
        return payment, refund
    if resolution == "reject":
        payment.status = Payment.Status.FAILED
        payment.failure_reason = f"Rejected by admin: {note}"[:255]
        payment.save(update_fields=["status", "failure_reason", "updated_at"])
        _release(payment)
        notify(payment.payer, Notification.Type.PAYMENT, t("Payment not received"),
               t("We checked payment {reference} and no money reached KaamNow. Contact support if you were charged.",
                 reference=payment.reference),
               {"payment_id": payment.pk})
        return payment, None
    raise BusinessRuleError(_("Unknown resolution."))
