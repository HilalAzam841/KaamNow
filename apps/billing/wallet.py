"""Worker wallet: what the platform owes a worker and what the worker owes the platform.

Each completed booking leaves money on one side:

- paid online (JazzCash / Easypaisa): the platform holds the customer's money and owes the worker
  their share (``Commission.worker_earning``);
- paid in cash: the worker holds the money and owes the platform its commission
  (``Commission.commission_amount``).

The wallet balance nets the two over bookings not yet settled. A positive balance is paid out
(the worker asks, an admin sends it and marks it paid); a negative one is paid by the worker
(online, or recorded by an admin when handed over in cash or by transfer). Each settlement takes
the bookings it covers with it, so nothing is counted twice.

One-off ``WorkerAdjustment`` rows (e.g. the worker's share of a customer refund) count the same way:
a positive one adds to what the platform owes, a negative one to what the worker owes.
"""

from decimal import Decimal

from django.db import IntegrityError, transaction
from django.db.models import Q, Sum
from django.utils import timezone
from django.utils.translation import gettext as _

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.common.i18n import money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import Commission, LedgerEntry, Payment, PlatformSettings, WorkerAdjustment, WorkerSettlement

ZERO = Decimal("0.00")
ONLINE = [m.value for m in Payment.ONLINE_METHODS]


def _open_commissions(worker):
    """Bookings whose money has not been settled with the worker yet."""
    return Commission.objects.filter(worker=worker, settlement__isnull=True).filter(
        Q(paid_via__in=ONLINE, status=Commission.Status.COLLECTED)
        | Q(paid_via=Payment.Method.CASH, status=Commission.Status.PENDING)
    )


def _open_adjustments(worker):
    return WorkerAdjustment.objects.filter(worker=worker, settlement__isnull=True)


def _totals(commissions, adjustments):
    agg = commissions.aggregate(
        held=Sum("worker_earning", filter=Q(paid_via__in=ONLINE)),
        owed=Sum("commission_amount", filter=Q(paid_via=Payment.Method.CASH)),
    )
    adj = adjustments.aggregate(plus=Sum("amount", filter=Q(amount__gt=0)), minus=Sum("amount", filter=Q(amount__lt=0)))
    held = (agg["held"] or ZERO) + (adj["plus"] or ZERO)
    owed = (agg["owed"] or ZERO) - (adj["minus"] or ZERO)
    return held, owed, held - owed


def _worker_totals(worker):
    return _totals(_open_commissions(worker), _open_adjustments(worker))


def summary(worker):
    held, owed, balance = _worker_totals(worker)
    cfg = PlatformSettings.load()
    open_settlement = WorkerSettlement.objects.filter(worker=worker, status=WorkerSettlement.Status.REQUESTED).first()
    last_payout = (
        WorkerSettlement.objects.filter(worker=worker, kind=WorkerSettlement.Kind.PAYOUT)
        .exclude(account_number="").first()
    )
    return {
        "earnings_held": held,
        "commission_owed": owed,
        "balance": balance,
        "min_payout": cfg.min_payout,
        "commission_debt_limit": cfg.commission_debt_limit,
        "can_request_payout": open_settlement is None and balance >= cfg.min_payout,
        "must_pay_commission": balance < 0,
        "offers_blocked": is_blocked_by_debt(worker, balance=balance, cfg=cfg),
        "open_settlement": open_settlement,
        "last_payout_account": (
            {"method": last_payout.method, "account_title": last_payout.account_title,
             "account_number": last_payout.account_number} if last_payout else None
        ),
        "settlements": WorkerSettlement.objects.filter(worker=worker)[:20],
    }


def is_blocked_by_debt(worker, *, balance=None, cfg=None):
    cfg = cfg or PlatformSettings.load()
    if not cfg.commission_debt_limit:
        return False
    if balance is None:
        balance = _worker_totals(worker)[2]
    return -balance > cfg.commission_debt_limit


def check_commission_debt(worker):
    """Called before a worker sends an offer."""
    balance = _worker_totals(worker)[2]
    if is_blocked_by_debt(worker, balance=balance):
        raise BusinessRuleError(
            _("You owe {amount} in commission. Pay it from your wallet to keep sending offers.").format(
                amount=money(-balance)),
            code="commission_due", status_code=403,
        )


def _lock(worker):
    """Locks the worker's unsettled bookings so two requests cannot settle the same money."""
    from apps.accounts.models import WorkerProfile

    WorkerProfile.objects.select_for_update().get(pk=worker.pk)
    if WorkerSettlement.objects.filter(worker=worker, status=WorkerSettlement.Status.REQUESTED).exists():
        raise ConflictError(_("You already have an open payout or commission payment."))
    commission_ids = list(_open_commissions(worker).select_for_update(of=("self",)).values_list("pk", flat=True))
    adjustment_ids = list(_open_adjustments(worker).select_for_update().values_list("pk", flat=True))
    held, owed, balance = _totals(
        Commission.objects.filter(pk__in=commission_ids), WorkerAdjustment.objects.filter(pk__in=adjustment_ids)
    )
    return (commission_ids, adjustment_ids), held, owed, balance


def _create(worker, ids, **fields):
    try:
        with transaction.atomic():
            settlement = WorkerSettlement.objects.create(worker=worker, **fields)
    except IntegrityError as exc:
        raise ConflictError(_("You already have an open payout or commission payment.")) from exc
    commission_ids, adjustment_ids = ids
    now = timezone.now()
    Commission.objects.filter(pk__in=commission_ids).update(settlement=settlement, updated_at=now)
    WorkerAdjustment.objects.filter(pk__in=adjustment_ids).update(settlement=settlement, updated_at=now)
    return settlement


def _release(settlement, status, note=""):
    settlement.status = status
    settlement.note = note[:255] or settlement.note
    settlement.save(update_fields=["status", "note", "updated_at"])
    settlement.commissions.update(settlement=None, updated_at=timezone.now())
    settlement.adjustments.update(settlement=None, updated_at=timezone.now())


def _finish(settlement, *, processed_by=None, reference=""):
    """Completes a settlement: its cash commissions are now collected; writes the ledger."""
    now = timezone.now()
    settlement.status = WorkerSettlement.Status.COMPLETED
    settlement.processed_by = processed_by
    settlement.processed_at = now
    if reference:
        settlement.reference = reference[:100]
    settlement.save(update_fields=["status", "processed_by", "processed_at", "reference", "updated_at"])
    settlement.commissions.filter(status=Commission.Status.PENDING).update(
        status=Commission.Status.COLLECTED, updated_at=now
    )
    entries = []
    if settlement.kind == WorkerSettlement.Kind.PAYOUT:
        entries.append(LedgerEntry(settlement=settlement, worker=settlement.worker, amount=settlement.amount,
                                   entry_type=LedgerEntry.EntryType.WORKER_PAYOUT,
                                   description=f"Payout via {settlement.get_method_display()}"))
    if settlement.commission_amount > 0:
        entries.append(LedgerEntry(settlement=settlement, payment=settlement.payment, worker=settlement.worker,
                                   amount=settlement.commission_amount,
                                   entry_type=LedgerEntry.EntryType.COMMISSION_SETTLEMENT,
                                   description="Cash commission settled"))
    LedgerEntry.objects.bulk_create(entries)
    return settlement


# --------------------------------------------------------------------------
# Worker actions
# --------------------------------------------------------------------------
@transaction.atomic
def request_payout(worker, *, method, account_title, account_number):
    if not worker.is_verified:
        raise BusinessRuleError(_("Payouts are available once your profile is verified."), status_code=403)
    ids, held, owed, balance = _lock(worker)
    cfg = PlatformSettings.load()
    if balance < cfg.min_payout:
        raise BusinessRuleError(
            _("You can ask for a payout once your balance reaches {amount}.").format(amount=money(cfg.min_payout))
        )
    return _create(
        worker, ids, kind=WorkerSettlement.Kind.PAYOUT, amount=balance, earnings_amount=held,
        commission_amount=owed, method=method, account_title=account_title.strip(),
        account_number=account_number.strip(),
    )


@transaction.atomic
def cancel_payout(settlement, worker):
    settlement = WorkerSettlement.objects.select_for_update().get(pk=settlement.pk)
    if settlement.worker_id != worker.pk:
        raise BusinessRuleError(_("This payout is not yours."), status_code=403)
    if settlement.kind != WorkerSettlement.Kind.PAYOUT or settlement.status != WorkerSettlement.Status.REQUESTED:
        raise ConflictError(_("Only an open payout request can be cancelled."))
    _release(settlement, WorkerSettlement.Status.CANCELLED)
    return settlement


@transaction.atomic
def pay_commission(worker, method):
    """The worker pays the commission they owe online. Settled only after the gateway callback
    is verified (see services.handle_gateway_callback)."""
    from .services import _create_payment

    if method not in ONLINE:
        raise BusinessRuleError(_("Pay with JazzCash or Easypaisa, or hand the commission to KaamNow's office."))
    ids, held, owed, balance = _lock(worker)
    if balance >= 0:
        raise BusinessRuleError(_("You do not owe any commission."))
    payment, checkout = _create_payment(
        purpose=Payment.Purpose.COMMISSION, payer=worker.user, amount=-balance, method=method
    )
    settlement = _create(
        worker, ids, kind=WorkerSettlement.Kind.COLLECTION, amount=-balance, earnings_amount=held,
        commission_amount=owed, method=method, payment=payment, reference=payment.reference,
    )
    return settlement, payment, checkout


def on_payment_completed(payment):
    """Called (inside the payment's transaction) when a commission payment is confirmed."""
    settlement = WorkerSettlement.objects.select_for_update().get(payment=payment)
    if settlement.status != WorkerSettlement.Status.REQUESTED:
        return settlement
    _finish(settlement)
    notify(settlement.worker.user, Notification.Type.PAYMENT, t("Commission paid"),
           t("Thank you. Your commission payment of {amount} is confirmed.", amount=money(settlement.amount)),
           {"payment_id": payment.pk})
    return settlement


def on_payment_closed(payment):
    """A commission payment failed or expired: its bookings go back to the wallet."""
    settlement = WorkerSettlement.objects.select_for_update().filter(payment=payment).first()
    if settlement and settlement.status == WorkerSettlement.Status.REQUESTED:
        _release(settlement, WorkerSettlement.Status.FAILED, payment.failure_reason)


# --------------------------------------------------------------------------
# Admin actions (audited by the caller's view through dashboard.services.audit)
# --------------------------------------------------------------------------
def _open_payout(settlement):
    settlement = WorkerSettlement.objects.select_for_update().select_related("worker__user").get(pk=settlement.pk)
    if settlement.kind != WorkerSettlement.Kind.PAYOUT or settlement.status != WorkerSettlement.Status.REQUESTED:
        raise ConflictError(_("This payout is already closed."))
    return settlement


@transaction.atomic
def mark_payout_paid(settlement, admin_user, reference):
    settlement = _finish(_open_payout(settlement), processed_by=admin_user, reference=reference)
    notify(settlement.worker.user, Notification.Type.PAYMENT, t("Payout sent"),
           t("We sent {amount} to your {method} account. Reference: {reference}.", amount=money(settlement.amount),
             method=t(settlement.get_method_display()), reference=settlement.reference),
           {"settlement_id": settlement.pk})
    return settlement


@transaction.atomic
def reject_payout(settlement, admin_user, reason):
    settlement = _open_payout(settlement)
    settlement.processed_by = admin_user
    settlement.processed_at = timezone.now()
    settlement.save(update_fields=["processed_by", "processed_at", "updated_at"])
    _release(settlement, WorkerSettlement.Status.REJECTED, reason)
    notify(settlement.worker.user, Notification.Type.PAYMENT, t("Payout not sent"),
           t("Your payout request was declined: {reason}", reason=reason),
           {"settlement_id": settlement.pk})
    return settlement


@transaction.atomic
def record_commission_received(worker, admin_user, *, method, reference):
    """The worker handed the commission they owe to the office (cash) or sent it by bank transfer."""
    ids, held, owed, balance = _lock(worker)
    if balance >= 0:
        raise BusinessRuleError(_("This worker does not owe any commission."))
    settlement = _create(
        worker, ids, kind=WorkerSettlement.Kind.COLLECTION, amount=-balance, earnings_amount=held,
        commission_amount=owed, method=method,
    )
    _finish(settlement, processed_by=admin_user, reference=reference)
    notify(worker.user, Notification.Type.PAYMENT, t("Commission paid"),
           t("Thank you. Your commission payment of {amount} is confirmed.", amount=money(settlement.amount)),
           {"settlement_id": settlement.pk})
    return settlement


def balances(owing=None):
    """Unsettled totals per worker, for the admin's list of who to pay and who owes."""
    rows = (
        Commission.objects.filter(settlement__isnull=True)
        .filter(Q(paid_via__in=ONLINE, status=Commission.Status.COLLECTED)
                | Q(paid_via=Payment.Method.CASH, status=Commission.Status.PENDING))
        .values("worker", "worker__user__full_name", "worker__user__phone")
        .annotate(held=Sum("worker_earning", filter=Q(paid_via__in=ONLINE)),
                  owed=Sum("commission_amount", filter=Q(paid_via=Payment.Method.CASH)))
    )
    adjustments = (
        WorkerAdjustment.objects.filter(settlement__isnull=True)
        .values("worker", "worker__user__full_name", "worker__user__phone")
        .annotate(held=Sum("amount", filter=Q(amount__gt=0)), owed=Sum("amount", filter=Q(amount__lt=0)))
    )
    per_worker = {}
    for r, sign in [(r, 1) for r in rows] + [(r, -1) for r in adjustments]:
        row = per_worker.setdefault(r["worker"], {
            "worker": r["worker"], "worker_name": r["worker__user__full_name"],
            "worker_phone": r["worker__user__phone"], "earnings_held": ZERO, "commission_owed": ZERO,
        })
        row["earnings_held"] += r["held"] or ZERO
        row["commission_owed"] += sign * (r["owed"] or ZERO)
    out = []
    for row in per_worker.values():
        balance = row["earnings_held"] - row["commission_owed"]
        if owing is True and balance >= 0 or owing is False and balance <= 0 or balance == 0:
            continue
        out.append({**row, "balance": balance})
    return sorted(out, key=lambda r: r["balance"])
