from django.utils.translation import gettext as _
from decimal import Decimal

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.jobs.models import Booking, BookingStatusLog, ServiceRequest
from apps.jobs.services import worker_can_bid_on, worker_distance_to_request
from apps.common.i18n import money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify, notify_many

from .models import Negotiation, Party, WorkerOffer


def validate_price(amount):
    amount = Decimal(amount)
    low = Decimal(settings.KAAMNOW["MIN_OFFER_PRICE"])
    high = Decimal(settings.KAAMNOW["MAX_OFFER_PRICE"])
    if amount < low or amount > high:
        raise BusinessRuleError(_("Price must be between Rs. {low} and Rs. {high}.").format(low=low, high=high))
    return amount.quantize(Decimal("0.01"))


def party_for(user, offer):
    if user.pk == offer.request.customer_id:
        return Party.CUSTOMER
    if user.pk == offer.worker.user_id:
        return Party.WORKER
    return None


def _rounds(offer):
    return offer.negotiations.filter(action__in=[Negotiation.Action.COUNTER, Negotiation.Action.REVISE]).count()


@transaction.atomic
def create_offer(worker, service_request, *, price, estimated_arrival_minutes, message="", additional_info=""):
    from apps.accounts.phone import require_verified

    require_verified(worker.user)
    # Lock the request row so offers cannot be created after it is booked.
    service_request = ServiceRequest.objects.select_for_update().get(pk=service_request.pk)
    if not service_request.is_open:
        raise ConflictError(_("This request is no longer accepting offers."))
    from apps.scheduling.services import check_worker_free

    if worker.can_receive_jobs:
        check_worker_free(worker, service_request)  # a clear reason: off hours, time off or another booking
    if not worker_can_bid_on(worker, service_request):
        raise BusinessRuleError(
            _("You are not eligible to bid on this request (check verification, availability, category and radius)."),
            status_code=http_status.HTTP_403_FORBIDDEN,
        )
    if WorkerOffer.objects.filter(request=service_request, worker=worker).exists():
        raise ConflictError(_("You have already made an offer on this request. Update it instead."))
    from apps.billing.services import check_daily_offer_limit

    check_daily_offer_limit(worker)
    from apps.billing.wallet import check_commission_debt

    check_commission_debt(worker)
    price = validate_price(price)
    try:
        with transaction.atomic():
            offer = WorkerOffer.objects.create(
                request=service_request, worker=worker, initial_price=price, current_price=price,
                awaiting=Party.CUSTOMER, estimated_arrival_minutes=estimated_arrival_minutes,
                message=message, additional_info=additional_info,
                distance_km=worker_distance_to_request(worker, service_request),
            )
    except IntegrityError as exc:
        raise ConflictError(_("You have already made an offer on this request.")) from exc
    Negotiation.objects.create(
        offer=offer, party=Party.WORKER, author=worker.user, action=Negotiation.Action.OFFER, amount=price,
        message=message,
    )
    notify(
        service_request.customer, Notification.Type.NEW_OFFER, t("New offer received"),
        t("{name} offered {amount} for '{title}'.", name=worker.user.full_name, amount=money(price),
          title=service_request.title),
        {"request_id": service_request.pk, "offer_id": offer.pk},
    )
    return offer


def _lock_pending_offer(offer):
    # Lock order is always request -> offer (same as accept_offer) to avoid deadlocks.
    ServiceRequest.objects.select_for_update().filter(pk=offer.request_id).first()
    offer = WorkerOffer.objects.select_for_update().select_related("request", "worker__user").get(pk=offer.pk)
    if not offer.is_pending:
        raise ConflictError(_("This offer can no longer be changed."))
    if not offer.request.is_open:
        raise ConflictError(_("This request is no longer open."))
    return offer


@transaction.atomic
def update_offer(offer, worker_user, **changes):
    """Worker edits their pending offer. A price change is recorded as a revision."""
    offer = _lock_pending_offer(offer)
    if offer.worker.user_id != worker_user.pk:
        raise BusinessRuleError(_("You can only edit your own offers."), status_code=403)
    fields = ["updated_at"]
    for attr in ("estimated_arrival_minutes", "message", "additional_info"):
        if attr in changes:
            setattr(offer, attr, changes[attr])
            fields.append(attr)
    if "price" in changes and Decimal(changes["price"]) != offer.current_price:
        if _rounds(offer) >= settings.KAAMNOW["MAX_NEGOTIATION_ROUNDS"]:
            raise BusinessRuleError(_("Maximum negotiation rounds reached."))
        price = validate_price(changes["price"])
        offer.current_price = price
        offer.awaiting = Party.CUSTOMER
        fields += ["current_price", "awaiting"]
        Negotiation.objects.create(
            offer=offer, party=Party.WORKER, author=worker_user, action=Negotiation.Action.REVISE, amount=price,
            message=changes.get("message", ""),
        )
        notify(
            offer.request.customer, Notification.Type.NEGOTIATION, t("Offer updated"),
            t("{name} updated their price to {amount}.", name=offer.worker.user.full_name, amount=money(price)),
            {"offer_id": offer.pk, "request_id": offer.request_id},
        )
    offer.save(update_fields=fields)
    return offer


@transaction.atomic
def negotiate(offer, user, *, action, amount=None, message=""):
    """
    Price negotiation between the request's customer and the offering worker.

    - action="counter": propose `amount`; the other party must respond next.
    - action="agree":   accept the other party's latest price. If the worker
      agrees, the customer can then confirm via accept_offer(). If the customer
      agrees, that is equivalent to accepting the offer (booking is created).
    """
    offer = _lock_pending_offer(offer)
    party = party_for(user, offer)
    if party is None:
        raise BusinessRuleError(_("You are not a participant in this negotiation."), status_code=403)
    if offer.awaiting != party:
        raise ConflictError(_("Waiting for the other party to respond."))

    other_user = offer.worker.user if party == Party.CUSTOMER else offer.request.customer

    if action == "counter":
        if amount is None:
            raise BusinessRuleError(_("Amount is required for a counter proposal."))
        if _rounds(offer) >= settings.KAAMNOW["MAX_NEGOTIATION_ROUNDS"]:
            raise BusinessRuleError(_("Maximum negotiation rounds reached. Accept or reject the current price."))
        amount = validate_price(amount)
        if amount == offer.current_price:
            raise BusinessRuleError(_("Counter amount must differ from the current price. Use 'agree' instead."))
        offer.current_price = amount
        offer.awaiting = Party.WORKER if party == Party.CUSTOMER else Party.CUSTOMER
        offer.save(update_fields=["current_price", "awaiting", "updated_at"])
        Negotiation.objects.create(
            offer=offer, party=party, author=user, action=Negotiation.Action.COUNTER, amount=amount, message=message
        )
        notify(
            other_user, Notification.Type.NEGOTIATION, t("New counter offer"),
            t("Counter proposal: {amount}.", amount=money(amount)), {"offer_id": offer.pk, "request_id": offer.request_id},
        )
        return offer, None

    if action == "agree":
        if party == Party.CUSTOMER:
            booking = accept_offer(offer, user, message=message)
            offer.refresh_from_db()
            return offer, booking
        # Worker agrees to the customer's price: hand back to the customer to confirm.
        offer.awaiting = Party.CUSTOMER
        offer.save(update_fields=["awaiting", "updated_at"])
        Negotiation.objects.create(
            offer=offer, party=party, author=user, action=Negotiation.Action.AGREE, amount=offer.current_price,
            message=message,
        )
        notify(
            other_user, Notification.Type.NEGOTIATION, t("Price agreed"),
            t("{name} agreed to {amount}. Confirm to book.", name=offer.worker.user.full_name,
              amount=money(offer.current_price)),
            {"offer_id": offer.pk, "request_id": offer.request_id},
        )
        return offer, None

    raise BusinessRuleError(_("Unknown negotiation action."))


def accept_offer(offer, customer_user, message=""):
    """
    Turns an offer into a booking.

    Concurrency safety:
      1. The ServiceRequest row is locked with SELECT ... FOR UPDATE, so two
         simultaneous accepts on the same request are serialised.
      2. The request status is re-checked inside the lock.
      3. Booking.request and Booking.offer are OneToOne (unique) columns, so the
         database itself rejects a second booking even if (1) were bypassed.
    """
    try:
        with transaction.atomic():
            service_request = ServiceRequest.objects.select_for_update().get(pk=offer.request_id)
            offer = WorkerOffer.objects.select_for_update().select_related("worker__user").get(pk=offer.pk)
            if service_request.customer_id != customer_user.pk:
                raise BusinessRuleError(_("Only the customer who posted the request can accept offers."), status_code=403)
            if service_request.status != ServiceRequest.Status.OPEN:
                raise ConflictError(_("This request has already been booked or closed."))
            if not offer.is_pending:
                raise ConflictError(_("This offer is no longer available."))
            if offer.awaiting != Party.CUSTOMER:
                raise ConflictError(_("You proposed a new price. Wait for the worker to respond before accepting."))
            worker = offer.worker
            if not (worker.is_verified and worker.user.is_active and not worker.user.is_suspended):
                raise ConflictError(_("This worker is no longer available."))
            if Booking.objects.filter(worker=worker, status__in=Booking.ACTIVE_STATUSES).count() >= 3:
                raise ConflictError(_("This worker has too many active bookings right now."))
            from apps.accounts.models import WorkerProfile
            from apps.scheduling.services import why_not_free

            # Serialise bookings of the same worker so two customers cannot book one time.
            WorkerProfile.objects.select_for_update().get(pk=worker.pk)
            if why_not_free(worker, service_request) == "busy":
                raise ConflictError(_("This worker already has a booking at that time. Choose another offer."))

            booking = Booking.objects.create(
                request=service_request, offer=offer, customer=customer_user, worker=worker,
                agreed_price=offer.current_price, emergency_fee=service_request.emergency_fee,
            )
            BookingStatusLog.objects.create(
                booking=booking, from_status="", to_status=Booking.Status.CONFIRMED, changed_by=customer_user
            )
            offer.status = WorkerOffer.Status.ACCEPTED
            offer.save(update_fields=["status", "updated_at"])
            Negotiation.objects.create(
                offer=offer, party=Party.CUSTOMER, author=customer_user, action=Negotiation.Action.ACCEPT,
                amount=offer.current_price, message=message,
            )
            service_request.status = ServiceRequest.Status.BOOKED
            service_request.save(update_fields=["status", "updated_at"])

            others = list(
                WorkerOffer.objects.select_related("worker__user")
                .filter(request=service_request, status=WorkerOffer.Status.PENDING)
                .exclude(pk=offer.pk)
            )
            WorkerOffer.objects.filter(pk__in=[o.pk for o in others]).update(
                status=WorkerOffer.Status.CLOSED, updated_at=timezone.now()
            )
            notify(
                worker.user, Notification.Type.OFFER_ACCEPTED, t("Offer accepted"),
                t("Your offer of {amount} was accepted. Booking #{id} is confirmed.",
                  amount=money(offer.current_price), id=booking.pk),
                {"booking_id": booking.pk, "offer_id": offer.pk},
            )
            if others:
                notify_many(
                    [o.worker.user for o in others], Notification.Type.OFFER_CLOSED, t("Request booked"),
                    t("'{title}' was booked with another provider.", title=service_request.title),
                    {"request_id": service_request.pk},
                )
            return booking
    except IntegrityError as exc:
        raise ConflictError(_("This request has already been booked.")) from exc


@transaction.atomic
def reject_offer(offer, user, reason=""):
    """Customer rejects an offer, or the worker withdraws their own offer."""
    offer = _lock_pending_offer(offer)
    party = party_for(user, offer)
    if party is None:
        raise BusinessRuleError(_("You are not a participant in this offer."), status_code=403)
    if party == Party.CUSTOMER:
        offer.status = WorkerOffer.Status.REJECTED
        action, recipient, title = Negotiation.Action.REJECT, offer.worker.user, t("Offer declined")
        notification_type = Notification.Type.OFFER_REJECTED
    else:
        offer.status = WorkerOffer.Status.WITHDRAWN
        action, recipient, title = Negotiation.Action.WITHDRAW, offer.request.customer, t("Offer withdrawn")
        notification_type = Notification.Type.NEGOTIATION
    offer.save(update_fields=["status", "updated_at"])
    Negotiation.objects.create(offer=offer, party=party, author=user, action=action, message=reason)
    notify(recipient, notification_type, title, reason or title, {"offer_id": offer.pk, "request_id": offer.request_id})
    return offer
