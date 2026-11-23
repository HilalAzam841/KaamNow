import secrets
from decimal import ROUND_HALF_UP, Decimal

from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import Commission, LedgerEntry, Payment, PlatformSettings

CENT = Decimal("0.01")


def calculate_commission(gross_amount, rate_percent):
    """Returns (commission, worker_earning), rounded half-up to paisa precision.

    >>> calculate_commission(Decimal("2000"), Decimal("10"))
    (Decimal('200.00'), Decimal('1800.00'))
    """
    gross = Decimal(gross_amount).quantize(CENT, rounding=ROUND_HALF_UP)
    rate = Decimal(rate_percent)
    if gross < 0 or rate < 0 or rate > 100:
        raise ValueError("Invalid amount or rate.")
    commission = (gross * rate / Decimal("100")).quantize(CENT, rounding=ROUND_HALF_UP)
    return commission, gross - commission


def record_commission(booking):
    """Idempotently records the platform commission for a completed booking."""
    existing = Commission.objects.filter(booking=booking).first()
    if existing:
        return existing
    rate = PlatformSettings.load().commission_percent
    commission, earning = calculate_commission(booking.agreed_price, rate)
    return Commission.objects.create(
        booking=booking, worker=booking.worker, gross_amount=booking.agreed_price, rate_percent=rate,
        commission_amount=commission, worker_earning=earning,
    )


def _reference():
    return f"KN-{timezone.now():%Y%m%d}-{secrets.token_hex(5).upper()}"


SUPPORTED_METHODS = {Payment.Method.CASH}


@transaction.atomic
def record_payment(booking, payer, method):
    """
    Customer records how they paid. The amount always comes from the booking's
    locked price, never from the client. Cash payments stay PENDING until the
    worker confirms receipt. Online gateways (JazzCash/Easypaisa) are not
    enabled yet: their success must come from a verified server callback.
    """
    from apps.jobs.models import Booking

    booking = Booking.objects.select_for_update().get(pk=booking.pk)
    if booking.customer_id != payer.pk:
        raise BusinessRuleError("You can only pay for your own bookings.", status_code=403)
    if booking.status != Booking.Status.COMPLETED:
        raise ConflictError("Payment can be recorded only after the job is completed.")
    if method not in SUPPORTED_METHODS:
        raise BusinessRuleError(f"{Payment.Method(method).label} payments are not available yet. Please pay in cash.")
    if Payment.objects.filter(booking=booking, status__in=[Payment.Status.PENDING, Payment.Status.COMPLETED]).exists():
        raise ConflictError("A payment for this booking already exists.")
    try:
        with transaction.atomic():
            payment = Payment.objects.create(
                booking=booking, payer=payer, amount=booking.agreed_price, method=method, reference=_reference()
            )
    except IntegrityError as exc:
        raise ConflictError("A payment for this booking already exists.") from exc
    notify(
        booking.worker.user, Notification.Type.PAYMENT, "Confirm cash received",
        f"Customer marked Rs. {payment.amount} as paid in cash for booking #{booking.pk}. Please confirm.",
        {"payment_id": payment.pk, "booking_id": booking.pk},
    )
    return payment


@transaction.atomic
def confirm_cash_payment(payment, worker_user):
    payment = Payment.objects.select_for_update().select_related("booking__worker__user", "booking").get(pk=payment.pk)
    booking = payment.booking
    if booking.worker.user_id != worker_user.pk:
        raise BusinessRuleError("Only the assigned worker can confirm cash receipt.", status_code=403)
    if payment.method != Payment.Method.CASH:
        raise BusinessRuleError("Only cash payments are confirmed manually.")
    if payment.status != Payment.Status.PENDING:
        raise ConflictError(f"Payment is already {payment.status}.")

    commission = record_commission(booking)
    payment.status = Payment.Status.COMPLETED
    payment.confirmed_at = timezone.now()
    payment.confirmed_by = worker_user
    payment.save(update_fields=["status", "confirmed_at", "confirmed_by", "updated_at"])

    LedgerEntry.objects.bulk_create([
        LedgerEntry(payment=payment, booking=booking, worker=booking.worker,
                    entry_type=LedgerEntry.EntryType.CUSTOMER_PAYMENT, amount=payment.amount,
                    description="Cash collected by worker"),
        LedgerEntry(payment=payment, booking=booking, worker=booking.worker,
                    entry_type=LedgerEntry.EntryType.PLATFORM_COMMISSION, amount=commission.commission_amount,
                    description=f"Platform commission {commission.rate_percent}% (owed by worker)"),
        LedgerEntry(payment=payment, booking=booking, worker=booking.worker,
                    entry_type=LedgerEntry.EntryType.WORKER_EARNING, amount=commission.worker_earning,
                    description="Worker net earning"),
    ])
    notify(
        payment.payer, Notification.Type.PAYMENT, "Payment confirmed",
        f"Your payment of Rs. {payment.amount} for booking #{booking.pk} is confirmed.",
        {"payment_id": payment.pk, "booking_id": booking.pk},
    )
    return payment
