import logging
import secrets
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .gateways import GatewayError, SignatureError, get_gateway
from .models import (
    Commission,
    FeaturedListing,
    FeaturedPlan,
    LedgerEntry,
    Payment,
    PlatformSettings,
    SubscriptionPlan,
    WorkerSubscription,
)

logger = logging.getLogger(__name__)
CENT = Decimal("0.01")


# --------------------------------------------------------------------------
# Commission
# --------------------------------------------------------------------------
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


def active_subscription(worker):
    now = timezone.now()
    return (
        WorkerSubscription.objects.select_related("plan")
        .filter(worker=worker, status=WorkerSubscription.Status.ACTIVE, ends_at__gt=now)
        .first()
    )


def current_plan(worker):
    """The plan whose benefits apply right now (active subscription, else the default free plan)."""
    sub = active_subscription(worker)
    if sub:
        return sub.plan
    return SubscriptionPlan.objects.filter(is_default=True, is_active=True).first()


def effective_commission_rate(worker):
    plan = current_plan(worker)
    if plan is not None and plan.commission_percent is not None:
        return plan.commission_percent
    return PlatformSettings.load().commission_percent


def record_commission(booking):
    """Idempotently records the platform commission for a completed booking.

    Commission is charged on the negotiated price only. The emergency fee is
    platform revenue and is tracked separately in the ledger.
    """
    existing = Commission.objects.filter(booking=booking).first()
    if existing:
        return existing
    rate = effective_commission_rate(booking.worker)
    commission, earning = calculate_commission(booking.agreed_price, rate)
    return Commission.objects.create(
        booking=booking, worker=booking.worker, gross_amount=booking.agreed_price, rate_percent=rate,
        commission_amount=commission, worker_earning=earning,
    )


# --------------------------------------------------------------------------
# Payments (shared)
# --------------------------------------------------------------------------
def _reference():
    return f"KN{timezone.now():%Y%m%d}{secrets.token_hex(5).upper()}"


def _create_payment(*, purpose, payer, amount, method, booking=None):
    """Creates a pending payment. For online methods also returns the gateway checkout."""
    checkout = None
    expires_at = None
    if method in Payment.ONLINE_METHODS:
        gateway = get_gateway(method)
        if not gateway.is_configured:
            raise BusinessRuleError(f"{Payment.Method(method).label} payments are not available right now.")
        expires_at = timezone.now() + timedelta(minutes=settings.ONLINE_PAYMENT_TTL_MINUTES)
    try:
        with transaction.atomic():
            payment = Payment.objects.create(
                purpose=purpose, booking=booking, payer=payer, amount=amount, method=method,
                reference=_reference(), expires_at=expires_at,
            )
    except IntegrityError as exc:
        raise ConflictError("A payment for this booking is already in progress.") from exc
    if method in Payment.ONLINE_METHODS:
        try:
            checkout = get_gateway(method).build_checkout(payment).as_dict()
        except GatewayError as exc:
            raise BusinessRuleError(str(exc)) from exc
    return payment, checkout


def _expire_if_stale(payment):
    if (
        payment.status == Payment.Status.PENDING
        and payment.is_online
        and payment.expires_at
        and payment.expires_at < timezone.now()
    ):
        payment.status = Payment.Status.EXPIRED
        payment.failure_reason = "Checkout expired before payment was confirmed."
        payment.save(update_fields=["status", "failure_reason", "updated_at"])
        return True
    return False


def _ledger(payment, entry_type, amount, description, booking=None, worker=None):
    return LedgerEntry(
        payment=payment, booking=booking, worker=worker, entry_type=entry_type, amount=amount,
        description=description,
    )


def _complete_payment(payment, confirmed_by=None):
    """Marks a locked payment completed, writes ledger entries and fulfils its purpose."""
    payment.status = Payment.Status.COMPLETED
    payment.confirmed_at = timezone.now()
    payment.confirmed_by = confirmed_by
    payment.save(update_fields=["status", "confirmed_at", "confirmed_by", "updated_at"])

    if payment.purpose == Payment.Purpose.BOOKING:
        booking = payment.booking
        commission = record_commission(booking)
        if payment.is_online and commission.status == Commission.Status.PENDING:
            # The platform received the money, so the commission is already collected.
            commission.status = Commission.Status.COLLECTED
            commission.save(update_fields=["status", "updated_at"])
        collected_by = "worker (cash)" if payment.method == Payment.Method.CASH else payment.get_method_display()
        entries = [
            _ledger(payment, LedgerEntry.EntryType.CUSTOMER_PAYMENT, payment.amount,
                    f"Customer payment collected by {collected_by}", booking, booking.worker),
            _ledger(payment, LedgerEntry.EntryType.PLATFORM_COMMISSION, commission.commission_amount,
                    f"Platform commission {commission.rate_percent}%", booking, booking.worker),
            _ledger(payment, LedgerEntry.EntryType.WORKER_EARNING, commission.worker_earning,
                    "Worker net earning", booking, booking.worker),
        ]
        if booking.emergency_fee > 0:
            entries.append(_ledger(payment, LedgerEntry.EntryType.EMERGENCY_FEE, booking.emergency_fee,
                                   "Emergency service fee", booking, booking.worker))
        LedgerEntry.objects.bulk_create(entries)
        notify(
            payment.payer, Notification.Type.PAYMENT, "Payment confirmed",
            f"Your payment of Rs. {payment.amount} for booking #{booking.pk} is confirmed.",
            {"payment_id": payment.pk, "booking_id": booking.pk},
        )
        if payment.is_online:
            notify(
                booking.worker.user, Notification.Type.PAYMENT, "Payment received",
                f"The customer paid Rs. {payment.amount} for booking #{booking.pk} via {payment.get_method_display()}.",
                {"payment_id": payment.pk, "booking_id": booking.pk},
            )

    elif payment.purpose == Payment.Purpose.SUBSCRIPTION:
        LedgerEntry.objects.create(
            payment=payment, worker=payment.subscription.worker, amount=payment.amount,
            entry_type=LedgerEntry.EntryType.SUBSCRIPTION_REVENUE,
            description=f"Subscription: {payment.subscription.plan.name}",
        )
        activate_subscription(payment.subscription)

    elif payment.purpose == Payment.Purpose.FEATURED_LISTING:
        LedgerEntry.objects.create(
            payment=payment, worker=payment.featured_listing.worker, amount=payment.amount,
            entry_type=LedgerEntry.EntryType.FEATURED_REVENUE,
            description=f"Featured listing: {payment.featured_listing.category.name}",
        )
        activate_featured_listing(payment.featured_listing)
    return payment


# --------------------------------------------------------------------------
# Booking payments
# --------------------------------------------------------------------------
@transaction.atomic
def record_payment(booking, payer, method):
    """
    Starts a payment for a completed booking. The amount always comes from the
    booking (negotiated price + emergency fee), never from the client.

    - cash: stays PENDING until the worker confirms receipt.
    - jazzcash / easypaisa: stays PENDING until the server verifies the
      gateway callback; returns the hosted-checkout details for the app.
    """
    from apps.jobs.models import Booking

    booking = Booking.objects.select_for_update().get(pk=booking.pk)
    if booking.customer_id != payer.pk:
        raise BusinessRuleError("You can only pay for your own bookings.", status_code=403)
    if booking.status != Booking.Status.COMPLETED:
        raise ConflictError("Payment can be recorded only after the job is completed.")
    live = Payment.objects.filter(booking=booking, status__in=[Payment.Status.PENDING, Payment.Status.COMPLETED])
    for existing in live.select_for_update():
        if existing.status == Payment.Status.COMPLETED:
            raise ConflictError("This booking is already paid.")
        if not _expire_if_stale(existing):
            if existing.method != method:
                # Switching method (e.g. JazzCash failed, paying cash instead) cancels the old attempt.
                existing.status = Payment.Status.FAILED
                existing.failure_reason = f"Replaced by a {method} payment."
                existing.save(update_fields=["status", "failure_reason", "updated_at"])
            else:
                raise ConflictError("A payment for this booking is already in progress.")
    payment, checkout = _create_payment(
        purpose=Payment.Purpose.BOOKING, payer=payer, amount=booking.total_amount, method=method, booking=booking
    )
    if method == Payment.Method.CASH:
        notify(
            booking.worker.user, Notification.Type.PAYMENT, "Confirm cash received",
            f"Customer marked Rs. {payment.amount} as paid in cash for booking #{booking.pk}. Please confirm.",
            {"payment_id": payment.pk, "booking_id": booking.pk},
        )
    return payment, checkout


@transaction.atomic
def confirm_cash_payment(payment, worker_user):
    payment = (
        Payment.objects.select_for_update(of=("self",)).select_related("booking__worker__user").get(pk=payment.pk)
    )
    if payment.purpose != Payment.Purpose.BOOKING or payment.booking is None:
        raise BusinessRuleError("Only booking payments can be confirmed by a worker.")
    if payment.booking.worker.user_id != worker_user.pk:
        raise BusinessRuleError("Only the assigned worker can confirm cash receipt.", status_code=403)
    if payment.method != Payment.Method.CASH:
        raise BusinessRuleError("Online payments are confirmed automatically by the payment gateway.")
    if payment.status != Payment.Status.PENDING:
        raise ConflictError(f"Payment is already {payment.status}.")
    return _complete_payment(payment, confirmed_by=worker_user)


# --------------------------------------------------------------------------
# Gateway callbacks
# --------------------------------------------------------------------------
def handle_gateway_callback(method, data):
    """
    Verifies a gateway callback server-side and settles the matching payment.
    Idempotent: replaying a callback for a settled payment changes nothing.
    Raises SignatureError / GatewayError when the data cannot be trusted.
    """
    result = get_gateway(method).verify_callback(data)  # raises on bad signature / failed inquiry
    with transaction.atomic():
        payment = (
            Payment.objects.select_for_update(of=("self",))
            .select_related("booking__worker__user", "payer")
            .filter(reference=result.reference)
            .first()
        )
        if payment is None:
            raise GatewayError(f"Unknown payment reference {result.reference!r}.")
        if payment.method != method:
            raise GatewayError("Callback gateway does not match the payment method.")
        if payment.status == Payment.Status.COMPLETED:
            return payment
        if payment.status != Payment.Status.PENDING:
            if result.success:
                # Money arrived for an expired/failed attempt: flag for manual review, never auto-settle.
                payment.status = Payment.Status.DISPUTED
                payment.failure_reason = "Gateway reported success after the payment was closed."
                payment.gateway_response = result.raw
                payment.save(update_fields=["status", "failure_reason", "gateway_response", "updated_at"])
                logger.warning("Late gateway success for payment %s", payment.reference)
            return payment

        payment.gateway_response = result.raw
        payment.gateway_transaction_id = result.transaction_id[:100]
        if result.amount is None or result.amount != payment.amount:
            payment.status = Payment.Status.DISPUTED
            payment.failure_reason = f"Amount mismatch: gateway {result.amount}, expected {payment.amount}."
            payment.save(update_fields=["status", "failure_reason", "gateway_response", "gateway_transaction_id",
                                        "updated_at"])
            logger.error("Payment %s amount mismatch: %s", payment.reference, payment.failure_reason)
            return payment
        if not result.success:
            payment.status = Payment.Status.FAILED
            payment.failure_reason = result.message[:255]
            payment.save(update_fields=["status", "failure_reason", "gateway_response", "gateway_transaction_id",
                                        "updated_at"])
            notify(payment.payer, Notification.Type.PAYMENT, "Payment failed",
                   f"Your {payment.get_method_display()} payment did not go through. Please try again.",
                   {"payment_id": payment.pk})
            return payment
        payment.save(update_fields=["gateway_response", "gateway_transaction_id", "updated_at"])
        return _complete_payment(payment)


def expire_stale_online_payments():
    count = 0
    stale = Payment.objects.filter(
        status=Payment.Status.PENDING, method__in=Payment.ONLINE_METHODS, expires_at__lt=timezone.now()
    )
    for payment_id in stale.values_list("id", flat=True):
        with transaction.atomic():
            payment = Payment.objects.select_for_update().get(pk=payment_id)
            if _expire_if_stale(payment):
                count += 1
                WorkerSubscription.objects.filter(payment=payment, status="pending_payment").update(
                    status=WorkerSubscription.Status.CANCELLED, updated_at=timezone.now()
                )
                FeaturedListing.objects.filter(payment=payment, status="pending_payment").update(
                    status=FeaturedListing.Status.CANCELLED, updated_at=timezone.now()
                )
    return count


# --------------------------------------------------------------------------
# Subscriptions
# --------------------------------------------------------------------------
def _require_online(method):
    if method not in Payment.ONLINE_METHODS:
        raise BusinessRuleError("Pay with JazzCash or Easypaisa. Contact support for other payment options.")


@transaction.atomic
def subscribe(worker, plan: SubscriptionPlan, method=None):
    """Starts a subscription. Free plans activate immediately; paid plans after verified payment."""
    if not plan.is_active:
        raise BusinessRuleError("This plan is not available.")
    if not worker.is_verified:
        raise BusinessRuleError("Your account must be verified before subscribing.", status_code=403)
    current = active_subscription(worker)
    if plan.is_free:
        if current and not current.plan.is_free:
            raise ConflictError("You already have an active paid plan. It will return to Free when it ends.")
        if current and current.plan_id == plan.pk:
            raise ConflictError("You are already on this plan.")
        subscription = WorkerSubscription.objects.create(worker=worker, plan=plan, amount=Decimal("0"))
        return activate_subscription(subscription), None

    _require_online(method)
    # Cancel any earlier unpaid attempt.
    WorkerSubscription.objects.filter(worker=worker, status=WorkerSubscription.Status.PENDING_PAYMENT).update(
        status=WorkerSubscription.Status.CANCELLED, updated_at=timezone.now()
    )
    payment, checkout = _create_payment(
        purpose=Payment.Purpose.SUBSCRIPTION, payer=worker.user, amount=plan.price, method=method
    )
    subscription = WorkerSubscription.objects.create(worker=worker, plan=plan, amount=plan.price, payment=payment)
    return subscription, checkout


def activate_subscription(subscription, activated_by=None):
    """Activates a subscription. Renewing the same plan extends it; switching plans replaces the old one."""
    subscription = WorkerSubscription.objects.select_for_update().select_related("plan", "worker__user").get(
        pk=subscription.pk
    )
    if subscription.status == WorkerSubscription.Status.ACTIVE:
        return subscription
    now = timezone.now()
    start = now
    current = (
        WorkerSubscription.objects.select_for_update()
        .filter(worker=subscription.worker, status=WorkerSubscription.Status.ACTIVE)
        .exclude(pk=subscription.pk)
        .first()
    )
    if current:
        if current.plan_id == subscription.plan_id and current.ends_at and current.ends_at > now:
            start = current.ends_at  # renewal: add time on top of what is left
        current.status = WorkerSubscription.Status.EXPIRED
        current.save(update_fields=["status", "updated_at"])
    subscription.status = WorkerSubscription.Status.ACTIVE
    subscription.starts_at = now
    subscription.ends_at = start + timedelta(days=subscription.plan.duration_days)
    subscription.activated_by = activated_by
    subscription.save(update_fields=["status", "starts_at", "ends_at", "activated_by", "updated_at"])
    notify(
        subscription.worker.user, Notification.Type.SUBSCRIPTION, f"{subscription.plan.name} plan active",
        f"Your {subscription.plan.name} plan is active until {timezone.localtime(subscription.ends_at):%d %b %Y}.",
        {"subscription_id": subscription.pk},
    )
    return subscription


@transaction.atomic
def admin_activate_subscription(subscription, admin_user, request=None):
    from apps.dashboard.models import AuditLog
    from apps.dashboard.services import audit

    subscription = WorkerSubscription.objects.select_for_update().get(pk=subscription.pk)
    if subscription.status != WorkerSubscription.Status.PENDING_PAYMENT:
        raise ConflictError(f"Subscription is {subscription.status}.")
    if subscription.payment_id:
        payment = Payment.objects.select_for_update().get(pk=subscription.payment_id)
        if payment.status == Payment.Status.PENDING:
            payment.status = Payment.Status.FAILED
            payment.failure_reason = "Closed: plan activated manually by admin."
            payment.save(update_fields=["status", "failure_reason", "updated_at"])
    subscription = activate_subscription(subscription, activated_by=admin_user)
    audit(admin_user, AuditLog.Action.SUBSCRIPTION_ACTIVATED, subscription, request,
          worker_id=subscription.worker_id, plan=subscription.plan.slug)
    return subscription


def offers_today(worker):
    start = timezone.localtime().replace(hour=0, minute=0, second=0, microsecond=0)
    return worker.offers.filter(created_at__gte=start).count()


def check_daily_offer_limit(worker):
    plan = current_plan(worker)
    limit = plan.daily_offer_limit if plan else None
    if limit is not None and offers_today(worker) >= limit:
        raise BusinessRuleError(
            f"Your {plan.name} plan allows {limit} offers per day. Upgrade your plan to send more.",
            status_code=http_status.HTTP_403_FORBIDDEN,
        )


# --------------------------------------------------------------------------
# Featured listings
# --------------------------------------------------------------------------
def _featured_slots_taken(category):
    now = timezone.now()
    return FeaturedListing.objects.filter(
        Q(status=FeaturedListing.Status.ACTIVE, ends_at__gt=now)
        | Q(status=FeaturedListing.Status.PENDING_PAYMENT, payment__expires_at__gt=now),
        category=category,
    ).count()


@transaction.atomic
def purchase_featured_listing(worker, plan: FeaturedPlan, category, method):
    from apps.catalog.models import ServiceCategory

    if not plan.is_active:
        raise BusinessRuleError("This featured plan is not available.")
    if not worker.is_verified:
        raise BusinessRuleError("Only verified workers can buy featured placement.", status_code=403)
    if not worker.services.filter(category=category, is_active=True).exists():
        raise BusinessRuleError("You can only feature a category you offer.")
    _require_online(method)
    ServiceCategory.objects.select_for_update().get(pk=category.pk)  # serialise slot counting per category
    if FeaturedListing.objects.filter(worker=worker, category=category, status=FeaturedListing.Status.ACTIVE,
                                      ends_at__gt=timezone.now()).exists():
        raise ConflictError("You are already featured in this category.")
    if _featured_slots_taken(category) >= settings.KAAMNOW["MAX_FEATURED_PER_CATEGORY"]:
        raise ConflictError("All featured slots in this category are taken. Please try again later.")
    FeaturedListing.objects.filter(worker=worker, category=category,
                                   status=FeaturedListing.Status.PENDING_PAYMENT).update(
        status=FeaturedListing.Status.CANCELLED, updated_at=timezone.now()
    )
    payment, checkout = _create_payment(
        purpose=Payment.Purpose.FEATURED_LISTING, payer=worker.user, amount=plan.price, method=method
    )
    listing = FeaturedListing.objects.create(
        worker=worker, category=category, plan=plan, amount=plan.price, payment=payment
    )
    return listing, checkout


def activate_featured_listing(listing):
    listing = FeaturedListing.objects.select_for_update().select_related("plan", "worker__user", "category").get(
        pk=listing.pk
    )
    if listing.status == FeaturedListing.Status.ACTIVE:
        return listing
    now = timezone.now()
    listing.status = FeaturedListing.Status.ACTIVE
    listing.starts_at = now
    listing.ends_at = now + timedelta(days=listing.plan.duration_days)
    listing.save(update_fields=["status", "starts_at", "ends_at", "updated_at"])
    notify(
        listing.worker.user, Notification.Type.FEATURED, "You are featured",
        f"You are now a sponsored {listing.category.name} until {timezone.localtime(listing.ends_at):%d %b %Y}.",
        {"featured_listing_id": listing.pk},
    )
    return listing


def featured_worker_ids(category):
    now = timezone.now()
    return set(
        FeaturedListing.objects.filter(
            category=category, status=FeaturedListing.Status.ACTIVE, starts_at__lte=now, ends_at__gt=now
        ).values_list("worker_id", flat=True)
    )


def expire_subscriptions_and_featured():
    now = timezone.now()
    subs = WorkerSubscription.objects.filter(status=WorkerSubscription.Status.ACTIVE, ends_at__lte=now).update(
        status=WorkerSubscription.Status.EXPIRED, updated_at=now
    )
    featured = FeaturedListing.objects.filter(status=FeaturedListing.Status.ACTIVE, ends_at__lte=now).update(
        status=FeaturedListing.Status.EXPIRED, updated_at=now
    )
    return {"subscriptions": subs, "featured_listings": featured}


__all__ = ["SignatureError", "GatewayError"]
