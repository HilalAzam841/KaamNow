"""Late cancellation fees.

A customer who cancels a booking late owes a small fee that goes to the worker (less the usual
commission) for the time they set aside or spent travelling:

- free within ``cancellation_free_minutes`` of booking (the customer changed their mind);
- free once the start time has passed and the worker has not set off (the worker is late);
- ``late_cancellation_fee`` when cancelling less than ``cancellation_window_minutes`` before the start;
- ``on_the_way_cancellation_fee`` once the worker is on the way or has arrived.

Workers never pay a fee for cancelling (their cancellations count against their level instead).
The fee is paid online, or an admin records it as received, or waives it. While online payments
are available, a customer with an unpaid fee cannot post or book a new job.
"""

from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.common.i18n import money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import CancellationFee

ZERO = Decimal("0.00")
CANCELLABLE = ("confirmed", "on_the_way", "arrived")


def _start_time(booking):
    req = booking.request
    return booking.created_at if req.is_emergency else req.preferred_time


def assess(booking, user, now=None):
    """What cancelling this booking right now would cost this user.

    Returns a dict: fee (Decimal, 0 when free), reason (CancellationFee.Reason or None),
    free_until (when a free cancellation ends, or None when it is already not free or always free)
    and fee_after (the fee from then on).
    """
    from apps.billing.models import PlatformSettings
    from apps.jobs.models import Booking

    now = now or timezone.now()
    out = {"fee": ZERO, "reason": None, "free_until": None, "fee_after": None}
    if user.pk != booking.customer_id or booking.status not in CANCELLABLE:
        return out
    cfg = PlatformSettings.load()
    if not cfg.cancellation_fee_enabled:
        return out
    grace_ends = booking.created_at + timedelta(minutes=cfg.cancellation_free_minutes)
    if booking.status in (Booking.Status.ON_THE_WAY, Booking.Status.ARRIVED):
        fee, reason = cfg.on_the_way_cancellation_fee, (
            CancellationFee.Reason.ON_THE_WAY if booking.status == Booking.Status.ON_THE_WAY
            else CancellationFee.Reason.ARRIVED)
        free_until = None
    else:
        if cfg.late_cancellation_fee <= 0:
            return out
        start = _start_time(booking)
        if now >= start and not booking.request.is_emergency:
            return out  # the worker is late and has not set off
        window_starts = start - timedelta(minutes=cfg.cancellation_window_minutes)
        fee, reason = cfg.late_cancellation_fee, CancellationFee.Reason.LATE
        free_until = max(window_starts, grace_ends)
        if now < free_until:
            out["free_until"] = free_until
            out["fee_after"] = min(cfg.late_cancellation_fee, booking.agreed_price)
            return out
    fee = min(fee, booking.agreed_price)
    if now < grace_ends and fee > 0:
        out.update(free_until=grace_ends, fee_after=fee)
        return out
    if fee <= 0:
        return out
    out.update(fee=fee.quantize(Decimal("0.01")), reason=reason)
    return out


def charge(booking, user, now=None):
    """Called inside cancel_booking (with the booking locked, before its status changes)."""
    from apps.billing.services import calculate_commission, effective_commission_rate

    result = assess(booking, user, now)
    if result["fee"] <= 0:
        return None
    rate = effective_commission_rate(booking.worker)
    commission, share = calculate_commission(result["fee"], rate)
    fee = CancellationFee.objects.create(
        booking=booking, customer=booking.customer, worker=booking.worker, reason=result["reason"],
        amount=result["fee"], commission_percent=rate, worker_share=share,
    )
    notify(
        booking.customer, Notification.Type.PAYMENT, t("Late cancellation fee"),
        t("Cancelling booking #{id} late costs {amount}. It goes to the worker for their time.",
          id=booking.pk, amount=money(fee.amount)),
        {"booking_id": booking.pk, "cancellation_fee_id": fee.pk},
    )
    notify(
        booking.worker.user, Notification.Type.PAYMENT, t("Cancellation fee for you"),
        t("The customer cancelled booking #{id} late. You get {amount} once they pay the fee.",
          id=booking.pk, amount=money(fee.worker_share)),
        {"booking_id": booking.pk, "cancellation_fee_id": fee.pk},
    )
    return fee


def online_payments_available():
    from apps.billing.gateways import get_gateway
    from apps.billing.models import Payment

    return any(get_gateway(m).is_configured for m in Payment.ONLINE_METHODS)


def unpaid_fees(customer):
    return CancellationFee.objects.filter(customer=customer, status=CancellationFee.Status.OWED)


def check_no_unpaid_fee(customer):
    """Customers pay late cancellation fees before posting or booking again (only when they can pay online)."""
    owed = list(unpaid_fees(customer).values_list("amount", flat=True))
    if owed and online_payments_available():
        raise BusinessRuleError(
            _("Please pay your late cancellation fee of {amount} first.").format(amount=money(sum(owed))),
            code="cancellation_fee_unpaid", status_code=402,
        )


def _lock_owed(fee):
    fee = CancellationFee.objects.select_for_update(of=("self",)).select_related(
        "booking", "worker__user", "customer").get(pk=fee.pk)
    if fee.status != CancellationFee.Status.OWED:
        raise ConflictError(_("This fee is already settled."))
    return fee


@transaction.atomic
def pay(fee, customer, method):
    """The customer pays a fee online. Settled only after the gateway callback is verified."""
    from apps.billing.models import Payment
    from apps.billing.services import _create_payment, _expire_if_stale

    if method not in Payment.ONLINE_METHODS:
        raise BusinessRuleError(_("Pay the fee with JazzCash or Easypaisa."))
    fee = _lock_owed(fee)
    if fee.customer_id != customer.pk:
        raise BusinessRuleError(_("You can only pay your own fees."), status_code=403)
    for existing in Payment.objects.select_for_update().filter(
        booking=fee.booking, purpose=Payment.Purpose.CANCELLATION_FEE, status=Payment.Status.PENDING,
    ):
        if not _expire_if_stale(existing):
            existing.status = Payment.Status.FAILED
            existing.failure_reason = f"Replaced by a new {method} payment."
            existing.save(update_fields=["status", "failure_reason", "updated_at"])
    return _create_payment(
        purpose=Payment.Purpose.CANCELLATION_FEE, payer=customer, amount=fee.amount, method=method,
        booking=fee.booking,
    )


@transaction.atomic
def record_received(fee, admin, reference=""):
    """An admin records a fee handed over at the office or by bank transfer."""
    from apps.billing.models import Payment
    from apps.billing.services import _complete_payment, _create_payment

    fee = _lock_owed(fee)
    for pending in Payment.objects.select_for_update().filter(
        booking=fee.booking, purpose=Payment.Purpose.CANCELLATION_FEE, status=Payment.Status.PENDING,
    ):
        pending.status = Payment.Status.FAILED
        pending.failure_reason = "Fee recorded as received by an admin."
        pending.save(update_fields=["status", "failure_reason", "updated_at"])
    payment, _checkout = _create_payment(
        purpose=Payment.Purpose.CANCELLATION_FEE, payer=fee.customer, amount=fee.amount,
        method=Payment.Method.CASH, booking=fee.booking,
    )
    if reference:
        payment.gateway_transaction_id = reference[:100]
        payment.save(update_fields=["gateway_transaction_id", "updated_at"])
    _complete_payment(payment, confirmed_by=admin)
    fee.refresh_from_db()
    return fee


def on_payment_completed(payment):
    """Called by billing (inside the payment's transaction) when a fee payment is confirmed."""
    from apps.billing.models import LedgerEntry, WorkerAdjustment

    fee = CancellationFee.objects.select_for_update().select_related("worker__user", "booking").get(
        booking=payment.booking)
    if fee.status != CancellationFee.Status.OWED:
        return fee
    fee.status, fee.payment, fee.paid_at = CancellationFee.Status.PAID, payment, timezone.now()
    fee.save(update_fields=["status", "payment", "paid_at", "updated_at"])
    if fee.worker_share > 0:
        WorkerAdjustment.objects.create(
            worker=fee.worker, amount=fee.worker_share,
            reason=f"Late cancellation fee for booking #{fee.booking_id}",
        )
    entries = [
        LedgerEntry(payment=payment, booking=fee.booking, worker=fee.worker, amount=fee.amount,
                    entry_type=LedgerEntry.EntryType.CANCELLATION_FEE,
                    description=f"Late cancellation fee ({fee.reason})"),
        LedgerEntry(payment=payment, booking=fee.booking, worker=fee.worker, amount=fee.amount - fee.worker_share,
                    entry_type=LedgerEntry.EntryType.PLATFORM_COMMISSION,
                    description=f"Platform commission {fee.commission_percent}% on cancellation fee"),
        LedgerEntry(payment=payment, booking=fee.booking, worker=fee.worker, amount=fee.worker_share,
                    entry_type=LedgerEntry.EntryType.WORKER_EARNING,
                    description="Worker share of cancellation fee"),
    ]
    LedgerEntry.objects.bulk_create(entries)
    notify(
        payment.payer, Notification.Type.PAYMENT, t("Fee paid"),
        t("Thanks, your late cancellation fee of {amount} is paid.", amount=money(fee.amount)),
        {"payment_id": payment.pk, "cancellation_fee_id": fee.pk},
    )
    notify(
        fee.worker.user, Notification.Type.PAYMENT, t("Cancellation fee received"),
        t("{amount} for cancelled booking #{id} was added to your wallet.", amount=money(fee.worker_share),
          id=fee.booking_id),
        {"cancellation_fee_id": fee.pk, "booking_id": fee.booking_id},
    )
    return fee


@transaction.atomic
def waive(fee, admin, reason):
    from apps.billing.models import Payment

    fee = _lock_owed(fee)
    Payment.objects.filter(
        booking=fee.booking, purpose=Payment.Purpose.CANCELLATION_FEE, status=Payment.Status.PENDING,
    ).update(status=Payment.Status.FAILED, failure_reason="Fee waived by an admin.", updated_at=timezone.now())
    fee.status, fee.waived_by, fee.waived_reason = CancellationFee.Status.WAIVED, admin, reason
    fee.save(update_fields=["status", "waived_by", "waived_reason", "updated_at"])
    notify(
        fee.customer, Notification.Type.PAYMENT, t("Fee waived"),
        t("Your late cancellation fee for booking #{id} was waived.", id=fee.booking_id),
        {"cancellation_fee_id": fee.pk, "booking_id": fee.booking_id},
    )
    return fee
