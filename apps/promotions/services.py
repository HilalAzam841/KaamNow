"""Working out discounts, holding them while a payment is open, and referral rewards.

The booking total is never taken from the client. A discount (promo code first, then credit) is
capped at ``PlatformSettings.max_discount_percent`` of the total, so every payment stays positive.
KaamNow pays the discount: the worker's earning is unchanged (see billing.wallet).
"""

from decimal import ROUND_HALF_UP, Decimal

from django.db.models import Q
from django.utils import timezone
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import CreditEntry, PromoCode, PromoRedemption, Referral, ReferralCode

CENT = Decimal("0.01")
ZERO = Decimal("0.00")


def _promo_error(message):
    return BusinessRuleError(message, code="promo_invalid")


def find_promo(code):
    code = (code or "").strip().upper()
    if not code:
        return None
    promo = PromoCode.objects.select_related("category").filter(code=code).first()
    if promo is None:
        raise _promo_error(_("This promo code does not exist."))
    return promo


def _uses(promo, user=None):
    qs = promo.redemptions.filter(status__in=[PromoRedemption.Status.PENDING, PromoRedemption.Status.APPLIED])
    if user is not None:
        qs = qs.filter(user=user)
    return qs.count()


def _has_paid_booking(user):
    from apps.billing.models import Payment

    return Payment.objects.filter(payer=user, purpose=Payment.Purpose.BOOKING, status=Payment.Status.COMPLETED).exists()


def promo_discount(promo, booking, user, *, ignore=None):
    """Checks the code against this booking and customer and returns the discount in rupees.
    ``ignore``: a payment whose own hold should not count (when re-checking under lock)."""
    now = timezone.now()
    total = booking.total_amount
    if not promo.is_active or (promo.starts_at and promo.starts_at > now):
        raise _promo_error(_("This promo code is not active."))
    if promo.ends_at and promo.ends_at < now:
        raise _promo_error(_("This promo code has expired."))
    if promo.category_id and promo.category_id != booking.request.category_id:
        raise _promo_error(_("This promo code is for {service} only.").format(service=promo.category.name))
    if total < promo.min_order:
        raise _promo_error(_("This promo code needs a booking of at least {amount}.").format(amount=money(promo.min_order)))
    if promo.first_booking_only and _has_paid_booking(user):
        raise _promo_error(_("This promo code is for your first booking only."))
    held = promo.redemptions.filter(payment=ignore).count() if ignore else 0
    if promo.max_uses is not None and _uses(promo) - held >= promo.max_uses:
        raise _promo_error(_("This promo code has been used up."))
    if _uses(promo, user) - held >= promo.max_uses_per_user:
        raise _promo_error(_("You have already used this promo code."))
    if promo.kind == PromoCode.Kind.PERCENT:
        amount = (total * promo.value / 100).quantize(CENT, ROUND_HALF_UP)
        if promo.max_discount is not None:
            amount = min(amount, promo.max_discount)
    else:
        amount = promo.value
    return min(amount, total)


def quote(booking, user, *, promo_code="", use_credit=False):
    """What the customer would pay. Raises when the promo code cannot be used."""
    from apps.billing.models import PlatformSettings

    total = booking.total_amount
    cap = (total * PlatformSettings.load().max_discount_percent / 100).quantize(CENT, ROUND_HALF_UP)
    promo = find_promo(promo_code)
    promo_amount = min(promo_discount(promo, booking, user), cap) if promo else ZERO
    balance = max(CreditEntry.balance(user), ZERO)
    credit = min(balance, cap - promo_amount) if use_credit else ZERO
    return {
        "total": total,
        "promo": promo,
        "promo_code": promo.code if promo else "",
        "promo_description": promo.description if promo else "",
        "promo_discount": promo_amount,
        "credit_balance": balance,
        "credit_used": credit,
        "discount": promo_amount + credit,
        "amount": total - promo_amount - credit,
        "max_discount": cap,
    }


def hold(payment, q, user):
    """Reserves the promo code and credit for an open payment (inside its transaction)."""
    if q["promo"] is not None:
        promo = PromoCode.objects.select_for_update().get(pk=q["promo"].pk)
        promo_discount(promo, payment.booking, user)  # re-checked under the lock: limits hold under races
        PromoRedemption.objects.create(promo=promo, user=user, payment=payment, amount=q["promo_discount"])
    if q["credit_used"] > 0:
        from apps.accounts.models import User

        User.objects.select_for_update().get(pk=user.pk)
        if CreditEntry.balance(user) < q["credit_used"]:
            raise BusinessRuleError(_("Your credit has changed. Please try again."))
        CreditEntry.objects.create(user=user, amount=-q["credit_used"], kind=CreditEntry.Kind.SPENT, payment=payment,
                                   note=f"Booking #{payment.booking_id}")


def _credit_net(payment):
    return sum((e.amount for e in payment.credit_entries.all()), ZERO)


def release(payment):
    """The payment failed, expired or was replaced: the code and credit can be used again."""
    PromoRedemption.objects.filter(payment=payment, status=PromoRedemption.Status.PENDING).update(
        status=PromoRedemption.Status.RELEASED, updated_at=timezone.now()
    )
    net = _credit_net(payment)
    if net < 0:
        CreditEntry.objects.create(user=payment.payer, amount=-net, kind=CreditEntry.Kind.RETURNED, payment=payment,
                                   note=f"Booking #{payment.booking_id}")


def on_completed(payment):
    """The booking payment went through: the discount is final, and the customer's inviter may be
    rewarded. Also handles a disputed payment accepted after its hold was released."""
    if payment.discount_amount > 0:
        redemption = PromoRedemption.objects.filter(payment=payment).first()
        if redemption and redemption.status != PromoRedemption.Status.APPLIED:
            redemption.status = PromoRedemption.Status.APPLIED
            redemption.save(update_fields=["status", "updated_at"])
        promo_part = redemption.amount if redemption else ZERO
        owed = payment.discount_amount - promo_part
        net = _credit_net(payment)
        if owed > 0 and -net < owed:
            CreditEntry.objects.create(user=payment.payer, amount=-(owed + net), kind=CreditEntry.Kind.SPENT,
                                       payment=payment, note=f"Booking #{payment.booking_id}")
    _reward_referrer(payment)


def _reward_referrer(payment):
    from apps.billing.models import PlatformSettings, WorkerAdjustment

    referral = Referral.objects.select_for_update().filter(
        referee=payment.payer, status=Referral.Status.PENDING
    ).select_related("referrer").first()
    if referral is None:
        return
    cfg = PlatformSettings.load()
    booking_total = payment.amount + payment.discount_amount
    if booking_total < cfg.referral_min_booking:
        return
    reward = cfg.referral_reward
    referral.status = Referral.Status.REWARDED
    referral.referrer_reward = reward
    referral.rewarded_payment = payment
    referral.rewarded_at = timezone.now()
    referral.save(update_fields=["status", "referrer_reward", "rewarded_payment", "rewarded_at", "updated_at"])
    if reward <= 0:
        return
    referrer = referral.referrer
    worker = getattr(referrer, "worker_profile", None) if referrer.role == referrer.Role.WORKER else None
    if worker is not None:
        # Workers get it as cash in their wallet, paid with their next payout.
        WorkerAdjustment.objects.create(worker=worker, amount=reward,
                                        reason=f"Invite reward: {payment.payer.full_name}"[:255])
        body = t("{name} paid their first booking. {amount} is added to your wallet.",
                 name=payment.payer.full_name, amount=money(reward))
    else:
        CreditEntry.objects.create(user=referrer, amount=reward, kind=CreditEntry.Kind.REFERRAL, referral=referral,
                                   note=payment.payer.full_name[:255])
        body = t("{name} paid their first booking. You have {amount} credit for your next booking.",
                 name=payment.payer.full_name, amount=money(reward))
    notify(referrer, Notification.Type.PAYMENT, t("Invite reward"), body, {"referral_id": referral.pk})


def apply_referral_code(user, code):
    """At sign-up: links the new customer to the inviter and gives the welcome credit."""
    from apps.billing.models import PlatformSettings

    code = (code or "").strip().upper()
    if not code:
        return None
    owner = ReferralCode.objects.filter(code=code).select_related("user").first()
    if owner is None or owner.user_id == user.pk:
        raise BusinessRuleError(_("This invite code does not exist."), code="referral_invalid")
    if user.role != user.Role.CUSTOMER:
        return None  # invites are for new customers; workers can still sign up
    credit = PlatformSettings.load().referral_welcome_credit
    referral = Referral.objects.create(referrer=owner.user, referee=user, welcome_credit=credit)
    if credit > 0:
        CreditEntry.objects.create(user=user, amount=credit, kind=CreditEntry.Kind.WELCOME, referral=referral,
                                   note=owner.user.full_name[:255])
    return referral


def summary(user):
    from apps.billing.models import PlatformSettings

    cfg = PlatformSettings.load()
    code = ReferralCode.for_user(user)
    made = Referral.objects.filter(referrer=user)
    from django.conf import settings

    return {
        "code": code.code,
        "invite_link": settings.INVITE_URL.format(code=code.code),
        "credit_balance": max(CreditEntry.balance(user), ZERO),
        "invited": made.count(),
        "rewarded": made.filter(status=Referral.Status.REWARDED).count(),
        "rewards_earned": sum((r.referrer_reward for r in made.filter(status=Referral.Status.REWARDED)), ZERO),
        "referral_reward": cfg.referral_reward,
        "welcome_credit": cfg.referral_welcome_credit,
        "min_booking": cfg.referral_min_booking,
        "credit_history": CreditEntry.objects.filter(user=user)[:20],
    }


def promo_stats(qs):
    """Use counts and discount given, per promo code."""
    from django.db.models import Count, Sum

    live = Q(redemptions__status__in=[PromoRedemption.Status.PENDING, PromoRedemption.Status.APPLIED])
    return qs.annotate(
        uses=Count("redemptions", filter=live),
        discount_given=Sum("redemptions__amount", filter=Q(redemptions__status=PromoRedemption.Status.APPLIED)),
    )

