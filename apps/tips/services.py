"""Tips: a customer thanks the worker with extra money after a job.

- Only the booking's customer can tip, only once the job is completed, and only for
  ``tip_window_days`` after that. One tip per booking; a tip that was not paid can be changed.
- The whole tip goes to the worker: KaamNow takes no commission.
- Online (JazzCash / Easypaisa): settled only after the gateway callback is verified on the
  server; the tip is then added to the worker's wallet and paid out with their earnings.
- Cash: the customer hands it over and records it; the worker confirms they received it (or says
  they did not, which cancels it). The worker already holds the money, so the wallet is unchanged.
"""

from datetime import timedelta
from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.common.i18n import money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import MAX_MESSAGE, MIN_TIP, Tip

SUGGESTIONS = (Decimal("100"), Decimal("200"), Decimal("500"))


def suggestions(cfg):
    return [s for s in SUGGESTIONS if s <= cfg.tip_max_amount]


def tip_window_ends(booking, cfg):
    if booking.completed_at is None:
        return None
    return booking.completed_at + timedelta(days=cfg.tip_window_days)


def can_tip(booking, user, now=None):
    """Whether this user may tip on this booking now (ignores an existing tip)."""
    from apps.billing.models import PlatformSettings
    from apps.jobs.models import Booking

    cfg = PlatformSettings.load()
    if not cfg.tips_enabled or user.pk != booking.customer_id or booking.status != Booking.Status.COMPLETED:
        return False
    ends = tip_window_ends(booking, cfg)
    return ends is not None and (now or timezone.now()) <= ends


def _clean_amount(amount, cfg):
    try:
        amount = Decimal(str(amount)).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise BusinessRuleError(_("Enter a valid amount.")) from exc
    if amount < MIN_TIP:
        raise BusinessRuleError(_("A tip must be at least {amount}.").format(amount=money(MIN_TIP)))
    if amount > cfg.tip_max_amount:
        raise BusinessRuleError(_("A tip can be at most {amount}.").format(amount=money(cfg.tip_max_amount)))
    return amount


def _close_pending(tip, reason):
    from apps.billing.models import Payment
    from apps.billing.services import _expire_if_stale

    if tip.payment_id is None:
        return
    payment = Payment.objects.select_for_update().get(pk=tip.payment_id)
    if payment.status == Payment.Status.PENDING and not _expire_if_stale(payment):
        payment.status = Payment.Status.FAILED
        payment.failure_reason = reason[:255]
        payment.save(update_fields=["status", "failure_reason", "updated_at"])


@transaction.atomic
def give_tip(booking, customer, *, amount, method, message=""):
    """Starts a tip. Returns (tip, checkout); checkout is the gateway form for online methods, else None.

    The amount is checked against the platform limits here, never trusted from the app.
    """
    from apps.billing.models import Payment, PlatformSettings
    from apps.billing.services import _create_payment
    from apps.jobs.models import Booking

    booking = Booking.objects.select_for_update(of=("self",)).select_related("worker__user").get(pk=booking.pk)
    if booking.customer_id != customer.pk:
        raise BusinessRuleError(_("Only the customer can tip for this job."), status_code=403)
    cfg = PlatformSettings.load()
    if not cfg.tips_enabled:
        raise BusinessRuleError(_("Tips are switched off right now."), code="tips_disabled")
    if booking.status != Booking.Status.COMPLETED:
        raise ConflictError(_("You can tip once the job is completed."))
    if not can_tip(booking, customer):
        raise ConflictError(_("Tips can be given up to {days} days after the job.").format(
            days=cfg.tip_window_days), code="tip_window_closed")
    if method not in Payment.Method.values:
        raise BusinessRuleError(_("Choose how you want to pay the tip."))
    amount = _clean_amount(amount, cfg)
    message = (message or "").strip()[:MAX_MESSAGE]

    tip = Tip.objects.select_for_update().filter(booking=booking).first()
    if tip is not None:
        if tip.status == Tip.Status.PAID:
            raise ConflictError(_("You already tipped for this job. Thank you!"), code="already_tipped")
        _close_pending(tip, f"Replaced by a new {method} tip.")
    payment, checkout = _create_payment(purpose=Payment.Purpose.TIP, payer=customer, amount=amount, method=method)
    if tip is None:
        tip = Tip(booking=booking, customer=customer, worker=booking.worker)
    tip.amount, tip.method, tip.message, tip.payment = amount, method, message, payment
    tip.status, tip.paid_at = Tip.Status.PENDING, None
    tip.save()
    if method == Payment.Method.CASH:
        notify(
            booking.worker.user, Notification.Type.PAYMENT, t("Confirm your cash tip"),
            t("{name} gave you a tip of {amount} in cash for booking #{id}. Please confirm you received it.",
              name=customer.full_name.split(" ")[0], amount=money(amount), id=booking.pk),
            {"tip_id": tip.pk, "booking_id": booking.pk},
        )
    return tip, checkout


def _lock_pending_cash(tip, worker_user):
    from apps.billing.models import Payment

    tip = Tip.objects.select_for_update(of=("self",)).select_related("worker__user", "customer", "payment").get(
        pk=tip.pk)
    if tip.worker.user_id != worker_user.pk:
        raise BusinessRuleError(_("Only the worker who got the tip can do this."), status_code=403)
    if tip.status != Tip.Status.PENDING:
        raise ConflictError(_("This tip is already settled."))
    if tip.payment is None or tip.payment.method != Payment.Method.CASH:
        raise BusinessRuleError(_("Online tips are confirmed automatically by the payment gateway."))
    return tip


@transaction.atomic
def confirm_cash(tip, worker_user):
    from apps.billing.models import Payment
    from apps.billing.services import _complete_payment

    tip = _lock_pending_cash(tip, worker_user)
    payment = Payment.objects.select_for_update().get(pk=tip.payment_id)
    if payment.status != Payment.Status.PENDING:
        raise ConflictError(_("This tip is already settled."))
    _complete_payment(payment, confirmed_by=worker_user)
    tip.refresh_from_db()
    return tip


@transaction.atomic
def decline_cash(tip, worker_user):
    """The worker says the cash tip never reached them."""
    tip = _lock_pending_cash(tip, worker_user)
    _close_pending(tip, "Worker said the cash tip was not received.")
    tip.status = Tip.Status.CANCELLED
    tip.save(update_fields=["status", "updated_at"])
    notify(
        tip.customer, Notification.Type.PAYMENT, t("Cash tip not received"),
        t("The worker says they did not receive your cash tip of {amount} for booking #{id}.",
          amount=money(tip.amount), id=tip.booking_id),
        {"tip_id": tip.pk, "booking_id": tip.booking_id},
    )
    return tip


def on_payment_completed(payment):
    """Called by billing (inside the payment's transaction) when a tip payment is confirmed."""
    from apps.billing.models import LedgerEntry, Payment, WorkerAdjustment

    tip = Tip.objects.select_for_update().select_related("worker__user", "customer").filter(payment=payment).first()
    if tip is None or tip.status == Tip.Status.PAID:
        return tip
    tip.status, tip.paid_at = Tip.Status.PAID, timezone.now()
    tip.save(update_fields=["status", "paid_at", "updated_at"])
    if payment.method == Payment.Method.CASH:
        description = "Tip handed to the worker in cash"
    else:
        description = f"Tip paid via {payment.get_method_display()}, owed to the worker"
        WorkerAdjustment.objects.create(worker=tip.worker, amount=tip.amount,
                                        reason=f"Tip for booking #{tip.booking_id}")
    LedgerEntry.objects.create(payment=payment, booking=tip.booking, worker=tip.worker, amount=tip.amount,
                               entry_type=LedgerEntry.EntryType.TIP, description=description)
    notify(
        tip.worker.user, Notification.Type.PAYMENT, t("You got a tip!"),
        t("{name} tipped you {amount} for booking #{id}.", name=tip.customer.full_name.split(" ")[0],
          amount=money(tip.amount), id=tip.booking_id)
        + (f" “{tip.message}”" if tip.message else ""),
        {"tip_id": tip.pk, "booking_id": tip.booking_id},
    )
    notify(
        tip.customer, Notification.Type.PAYMENT, t("Tip sent"),
        t("Thank you! Your tip of {amount} went to the worker.", amount=money(tip.amount)),
        {"tip_id": tip.pk, "booking_id": tip.booking_id, "payment_id": payment.pk},
    )
    return tip


def summary(worker):
    from django.db.models import Count, Sum

    agg = Tip.objects.filter(worker=worker, status=Tip.Status.PAID).aggregate(count=Count("id"), total=Sum("amount"))
    return {"count": agg["count"] or 0, "total": agg["total"] or Decimal("0.00")}
