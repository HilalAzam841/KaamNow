from django.utils.translation import gettext as _, ngettext
import hashlib
import hmac
import secrets
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.db.models import F
from django.utils import timezone
from rest_framework import status as http_status

from apps.accounts.models import WorkerProfile
from apps.common.exceptions import BusinessRuleError
from apps.common.geo import bounding_box, get_geo_backend, haversine_km
from apps.common.i18n import category_name, money, t
from apps.notifications.models import Notification
from apps.notifications.services import notify, notify_many

from .models import Booking, BookingStatusLog, ServiceRequest, ServiceRequestImage


# --------------------------------------------------------------------------
# Worker discovery
# --------------------------------------------------------------------------
def eligible_workers_queryset(category):
    """Workers that are verified, online, active and offer `category`."""
    return (
        WorkerProfile.objects.select_related("user")
        .filter(
            verification_status=WorkerProfile.VerificationStatus.VERIFIED,
            is_available=True,
            user__is_active=True,
            user__is_suspended=False,
            services__category=category,
            services__is_active=True,
        )
        .distinct()
    )


def find_nearby_workers(category, latitude, longitude, exclude_user=None, sponsored_first=False, window=None):
    """Matching workers sorted by distance.

    With window=(start, end) only workers free then are returned (working hours, time off and
    other bookings; see apps.scheduling).

    With sponsored_first=True (customer-facing search results), workers with an
    active featured listing in the category come first and are flagged
    `is_sponsored` so the app can label them clearly.
    """
    from apps.billing.services import featured_worker_ids

    qs = eligible_workers_queryset(category)
    if exclude_user is not None:
        qs = qs.exclude(user=exclude_user)
    workers = get_geo_backend().workers_covering_point(qs, latitude, longitude)
    if window is not None:
        from apps.scheduling.services import free_workers

        workers = free_workers(workers, *window)
    sponsored = featured_worker_ids(category)
    for worker in workers:
        worker.is_sponsored = worker.pk in sponsored
    if sponsored_first:
        workers.sort(key=lambda w: (not w.is_sponsored, w.distance_km))
    return workers


def worker_distance_to_request(worker, service_request):
    if worker.base_latitude is None or worker.base_longitude is None:
        return None
    return round(
        haversine_km(worker.base_latitude, worker.base_longitude, service_request.latitude, service_request.longitude),
        2,
    )


def worker_can_bid_on(worker, service_request):
    """True when the worker is eligible to see and bid on this open request."""
    if not worker.can_receive_jobs or not service_request.is_open:
        return False
    if service_request.customer_id == worker.user_id:
        return False
    if service_request.invited_worker_id and service_request.invited_worker_id != worker.pk:
        return False
    if not worker.services.filter(category_id=service_request.category_id, is_active=True).exists():
        return False
    distance = worker_distance_to_request(worker, service_request)
    if distance is None or distance > float(worker.service_radius_km):
        return False
    from apps.scheduling.services import request_fits_worker

    return request_fits_worker(worker, service_request)


def open_requests_for_worker(worker):
    """Open requests in the worker's categories within the worker's radius."""
    if not worker.can_receive_jobs or worker.base_latitude is None:
        return []
    category_ids = list(worker.services.filter(is_active=True).values_list("category_id", flat=True))
    box = bounding_box(worker.base_latitude, worker.base_longitude, float(worker.service_radius_km))
    candidates = (
        ServiceRequest.objects.select_related("category", "customer")
        .prefetch_related("images")
        .filter(
            status=ServiceRequest.Status.OPEN,
            category_id__in=category_ids,
            latitude__gte=Decimal(str(box.min_lat)), latitude__lte=Decimal(str(box.max_lat)),
            longitude__gte=Decimal(str(box.min_lng)), longitude__lte=Decimal(str(box.max_lng)),
        )
        .exclude(customer=worker.user)
        .filter(Q(invited_worker__isnull=True) | Q(invited_worker=worker))
        .order_by("-created_at")
    )
    results = []
    for req in candidates:
        distance = worker_distance_to_request(worker, req)
        if distance is not None and distance <= float(worker.service_radius_km):
            req.distance_km = distance
            results.append(req)
    # Only jobs the worker is free for (working hours, time off, other bookings).
    if results:
        from apps.scheduling.services import request_fits_worker, schedules_for

        starts = [r.window[0] for r in results]
        ends = [r.window[1] for r in results]
        schedule = schedules_for([worker], min(starts), max(ends))[worker.pk]
        results = [r for r in results if request_fits_worker(worker, r, schedule)]
    # Emergencies first, then newest.
    results.sort(key=lambda r: (not r.is_emergency, -r.created_at.timestamp()))
    return results


# --------------------------------------------------------------------------
# Service requests
# --------------------------------------------------------------------------
@transaction.atomic
def create_service_request(customer, images=None, **data):
    from apps.accounts.phone import require_verified
    from apps.billing.models import PlatformSettings

    require_verified(customer)
    from apps.cancellations.services import check_no_unpaid_fee

    check_no_unpaid_fee(customer)

    category = data["category"]
    if not category.is_active:
        raise BusinessRuleError(_("This service category is not available."))
    if data.get("is_emergency"):
        platform = PlatformSettings.load()
        if not platform.emergency_enabled:
            raise BusinessRuleError(_("Emergency service is not available right now."))
        data["emergency_fee"] = platform.emergency_fee
    else:
        data["emergency_fee"] = Decimal("0")
    invited = data.get("invited_worker")
    if invited is not None and data.get("is_emergency"):
        raise BusinessRuleError(_("Emergency jobs go to every worker nearby. Turn off emergency to book one worker."))
    service_request = ServiceRequest.objects.create(customer=customer, **data)
    for image in images or []:
        ServiceRequestImage.objects.create(request=service_request, image=image)

    if invited is not None:
        # Book again: only this worker hears about the job. Raising here rolls the request back.
        check_worker_can_be_invited(invited, service_request)
        transaction.on_commit(lambda: notify_many(
            [invited.user], Notification.Type.NEW_REQUEST,
            t("{name} wants to book you again", name=customer.full_name.split(" ")[0]),
            service_request.title,
            {"request_id": service_request.pk, "is_emergency": False, "is_direct": True},
        ))
        service_request.matched_workers_count = 1
        return service_request

    service_request.matched_workers_count = len(_notify_matching_workers(service_request))
    return service_request


def _notify_matching_workers(service_request, exclude_worker=None):
    """Alerts the free matching workers nearby about an open job. Returns them."""
    category = service_request.category
    window = None if service_request.is_emergency else service_request.window
    workers = find_nearby_workers(category, service_request.latitude, service_request.longitude,
                                  exclude_user=service_request.customer, window=window)
    if exclude_worker is not None:
        workers = [w for w in workers if w.pk != exclude_worker.pk]
    if workers:
        title = (
            t("URGENT: New {category} request nearby", category=category_name(category))
            if service_request.is_emergency
            else t("New {category} request nearby", category=category_name(category))
        )
        transaction.on_commit(lambda: notify_many(
            [w.user for w in workers], Notification.Type.NEW_REQUEST,
            title,
            service_request.title,
            {"request_id": service_request.pk, "is_emergency": service_request.is_emergency},
        ))
    return workers


INVITE_MESSAGES = {
    "off_hours": lambda: _("This worker does not work at that time. Choose one of their free times."),
    "time_off": lambda: _("This worker is off on that day. Choose another day."),
    "busy": lambda: _("This worker already has a job at that time. Choose another time."),
}


def check_worker_can_be_invited(worker, service_request):
    """Raises a 409 with a clear reason when this worker cannot take the job."""
    from apps.scheduling.services import why_not_free

    def refuse(message, code):
        raise BusinessRuleError(message, code=code, status_code=http_status.HTTP_409_CONFLICT)

    if worker.user_id == service_request.customer_id:
        refuse(_("You cannot book yourself."), "worker_unavailable")
    if not worker.can_receive_jobs or not worker.services.filter(
        category_id=service_request.category_id, is_active=True
    ).exists():
        refuse(_("This worker is not taking {category} jobs right now. Post your job to everyone instead.").format(
            category=service_request.category.display_name), "worker_unavailable")
    distance = worker_distance_to_request(worker, service_request)
    if distance is None or distance > float(worker.service_radius_km):
        refuse(_("This address is outside the area this worker covers. Post your job to everyone instead."),
               "worker_too_far")
    reason = why_not_free(worker, service_request)
    if reason:
        refuse(INVITE_MESSAGES[reason](), f"worker_{reason}")


@transaction.atomic
def open_to_everyone(service_request, *, declined_by=None):
    """Turns a book-again job into a normal one: every free matching worker nearby can now offer.

    Called by the customer, or when the invited worker says they cannot take it (declined_by).
    """
    service_request = ServiceRequest.objects.select_for_update(of=("self",)).select_related(
        "category", "customer", "invited_worker__user"
    ).get(pk=service_request.pk)
    if not service_request.is_open:
        raise BusinessRuleError(_("This job is no longer open."), status_code=http_status.HTTP_409_CONFLICT)
    invited = service_request.invited_worker
    if invited is None:
        raise BusinessRuleError(_("This job is already open to every worker nearby."),
                                status_code=http_status.HTTP_409_CONFLICT)
    if declined_by is not None and declined_by.pk != invited.pk:
        raise BusinessRuleError(_("This job was not sent to you."), status_code=http_status.HTTP_403_FORBIDDEN)
    from apps.offers.models import WorkerOffer

    if declined_by is not None and WorkerOffer.objects.filter(
        request=service_request, worker=invited, status=WorkerOffer.Status.PENDING
    ).exists():
        raise BusinessRuleError(_("Withdraw your offer first."), status_code=http_status.HTTP_409_CONFLICT)

    service_request.invited_worker = None
    service_request.save(update_fields=["invited_worker", "updated_at"])
    workers = _notify_matching_workers(service_request, exclude_worker=invited)
    if declined_by is not None:
        customer = service_request.customer
        transaction.on_commit(lambda: notify_many(
            [customer], Notification.Type.SYSTEM,
            t("{name} cannot take this job", name=invited.user.full_name.split(" ")[0]),
            t("We sent \"{title}\" to {count} other workers nearby.", title=service_request.title, count=len(workers)),
            {"request_id": service_request.pk},
        ))
    service_request.matched_workers_count = len(workers)
    return service_request


@transaction.atomic
def cancel_service_request(service_request, user, reason=""):
    from apps.offers.models import WorkerOffer

    service_request = ServiceRequest.objects.select_for_update().get(pk=service_request.pk)
    if service_request.status != ServiceRequest.Status.OPEN:
        raise BusinessRuleError(
            _("Only open requests can be cancelled. Cancel the booking instead."), status_code=http_status.HTTP_409_CONFLICT
        )
    service_request.status = ServiceRequest.Status.CANCELLED
    service_request.cancelled_at = timezone.now()
    service_request.cancel_reason = reason
    service_request.save(update_fields=["status", "cancelled_at", "cancel_reason", "updated_at"])

    pending = list(
        WorkerOffer.objects.select_related("worker__user").filter(
            request=service_request, status=WorkerOffer.Status.PENDING
        )
    )
    WorkerOffer.objects.filter(pk__in=[o.pk for o in pending]).update(
        status=WorkerOffer.Status.CLOSED, updated_at=timezone.now()
    )
    if pending:
        notify_many(
            [o.worker.user for o in pending], Notification.Type.REQUEST_CANCELLED,
            t("Request cancelled"), t("The customer cancelled '{title}'.", title=service_request.title),
            {"request_id": service_request.pk},
        )
    return service_request


# --------------------------------------------------------------------------
# Bookings
# --------------------------------------------------------------------------
# Allowed worker-driven transitions. Completion goes through OTP verification.
WORKER_TRANSITIONS = {
    Booking.Status.CONFIRMED: {Booking.Status.ON_THE_WAY},
    Booking.Status.ON_THE_WAY: {Booking.Status.ARRIVED},
    Booking.Status.ARRIVED: {Booking.Status.IN_PROGRESS},
}
STATUS_TIMESTAMP = {
    Booking.Status.ON_THE_WAY: "on_the_way_at",
    Booking.Status.ARRIVED: "arrived_at",
    Booking.Status.IN_PROGRESS: "started_at",
}


def _log(booking, from_status, to_status, user, note=""):
    from apps.common.realtime import broadcast_to_booking

    BookingStatusLog.objects.create(
        booking=booking, from_status=from_status, to_status=to_status, changed_by=user, note=note
    )
    broadcast_to_booking(booking.pk, "booking.status", {"booking": booking.pk, "from": from_status,
                                                        "to": to_status, "note": note})


STATUS_ALERTS = {
    Booking.Status.ON_THE_WAY: t("Your worker is on the way."),
    Booking.Status.ARRIVED: t("Your worker has arrived."),
    Booking.Status.IN_PROGRESS: t("Your worker has started the job."),
}


@transaction.atomic
def update_booking_status(booking, worker_user, new_status, note=""):
    booking = Booking.objects.select_for_update().get(pk=booking.pk)
    if booking.worker.user_id != worker_user.pk:
        raise BusinessRuleError(_("Only the assigned worker can update this booking."), status_code=403)
    allowed = WORKER_TRANSITIONS.get(booking.status, set())
    if new_status not in allowed:
        raise BusinessRuleError(
            _("This status change is not allowed right now."), status_code=http_status.HTTP_409_CONFLICT
        )
    old = booking.status
    booking.status = new_status
    setattr(booking, STATUS_TIMESTAMP[new_status], timezone.now())
    booking.save(update_fields=["status", STATUS_TIMESTAMP[new_status], "updated_at"])
    _log(booking, old, new_status, worker_user, note)
    notify(
        booking.customer, Notification.Type.BOOKING_STATUS, t("Booking update"),
        STATUS_ALERTS.get(new_status, t("Your booking was updated.")),
        {"booking_id": booking.pk, "status": new_status},
    )
    return booking


@transaction.atomic
def cancel_booking(booking, user, reason):
    booking = Booking.objects.select_for_update().select_related("request", "worker__user", "customer").get(pk=booking.pk)
    if booking.status not in (Booking.Status.CONFIRMED, Booking.Status.ON_THE_WAY, Booking.Status.ARRIVED):
        raise BusinessRuleError(
            _("This booking can no longer be cancelled."), status_code=http_status.HTTP_409_CONFLICT
        )
    from apps.cancellations.services import charge as charge_cancellation_fee

    charge_cancellation_fee(booking, user)  # before the status changes: the fee depends on it
    old = booking.status
    booking.status = Booking.Status.CANCELLED
    booking.cancelled_at = timezone.now()
    booking.cancelled_by = user
    booking.cancel_reason = reason
    booking.completion_otp_hash = ""
    booking.save(update_fields=[
        "status", "cancelled_at", "cancelled_by", "cancel_reason", "completion_otp_hash", "updated_at",
    ])
    ServiceRequest.objects.filter(pk=booking.request_id).update(
        status=ServiceRequest.Status.CANCELLED, cancelled_at=timezone.now(), cancel_reason=f"Booking cancelled: {reason}"
    )
    _log(booking, old, Booking.Status.CANCELLED, user, reason)
    if user.pk == booking.worker.user_id:
        from apps.levels.services import refresh as refresh_level

        refresh_level(booking.worker_id)
    other = booking.worker.user if user.pk == booking.customer_id else booking.customer
    notify(
        other, Notification.Type.BOOKING_CANCELLED, t("Booking cancelled"),
        t("Booking #{id} was cancelled. Reason: {reason}", id=booking.pk, reason=reason), {"booking_id": booking.pk},
    )
    return booking


# --------------------------------------------------------------------------
# Completion OTP
# --------------------------------------------------------------------------
def _hash_otp(booking_id, otp):
    key = settings.SECRET_KEY.encode()
    return hmac.new(key, f"booking:{booking_id}:otp:{otp}".encode(), hashlib.sha256).hexdigest()


def _generate_otp():
    length = settings.KAAMNOW["OTP_LENGTH"]
    return f"{secrets.randbelow(10 ** length):0{length}d}"


@transaction.atomic
def issue_completion_otp(booking, customer_user):
    """Creates a fresh completion OTP and returns the plaintext ONLY to the caller (the customer)."""
    booking = Booking.objects.select_for_update().get(pk=booking.pk)
    if booking.customer_id != customer_user.pk:
        raise BusinessRuleError(_("Only the customer can request the completion code."), status_code=403)
    if booking.status != Booking.Status.IN_PROGRESS:
        raise BusinessRuleError(
            _("A completion code is available once work has started."), status_code=http_status.HTTP_409_CONFLICT
        )
    cfg = settings.KAAMNOW
    now = timezone.now()
    if booking.completion_otp_sent_at and (now - booking.completion_otp_sent_at).total_seconds() < cfg[
        "OTP_RESEND_COOLDOWN_SECONDS"
    ]:
        raise BusinessRuleError(_("Please wait before requesting a new code."), status_code=http_status.HTTP_429_TOO_MANY_REQUESTS)

    otp = _generate_otp()
    booking.completion_otp_hash = _hash_otp(booking.pk, otp)
    booking.completion_otp_expires_at = now + timedelta(minutes=cfg["OTP_TTL_MINUTES"])
    booking.completion_otp_attempts = 0
    booking.completion_otp_sent_at = now
    booking.save(update_fields=[
        "completion_otp_hash", "completion_otp_expires_at", "completion_otp_attempts", "completion_otp_sent_at",
        "updated_at",
    ])
    return otp, booking.completion_otp_expires_at


def _finalize_completion(booking, user, via):
    from apps.billing.services import record_commission

    old = booking.status
    booking.status = Booking.Status.COMPLETED
    booking.completed_at = timezone.now()
    booking.completed_via = via
    booking.completion_otp_hash = ""
    booking.completion_otp_expires_at = None
    booking.save(update_fields=[
        "status", "completed_at", "completed_via", "completion_otp_hash", "completion_otp_expires_at", "updated_at",
    ])
    WorkerProfile.objects.filter(pk=booking.worker_id).update(completed_jobs_count=F("completed_jobs_count") + 1)
    _log(booking, old, Booking.Status.COMPLETED, user, f"Completed via {via}")
    from apps.levels.services import refresh as refresh_level

    refresh_level(booking.worker_id)
    record_commission(booking)
    for recipient in (booking.customer, booking.worker.user):
        notify(
            recipient, Notification.Type.BOOKING_COMPLETED, t("Job completed"),
            t("Booking #{id} is complete. Amount: {amount}.", id=booking.pk, amount=money(booking.agreed_price)), {"booking_id": booking.pk},
        )
    return booking


class OTPVerificationFailed(BusinessRuleError):
    default_code = "invalid_otp"


def complete_booking_with_otp(booking, worker_user, otp):
    """Worker submits the OTP the customer shared. Attempts are counted even on failure."""
    with transaction.atomic():
        booking = Booking.objects.select_for_update().select_related("worker__user", "customer").get(pk=booking.pk)
        if booking.worker.user_id != worker_user.pk:
            raise BusinessRuleError(_("Only the assigned worker can submit the completion code."), status_code=403)
        if booking.status != Booking.Status.IN_PROGRESS:
            raise BusinessRuleError(_("Booking is not in progress."), status_code=http_status.HTTP_409_CONFLICT)
        if not booking.completion_otp_hash or not booking.completion_otp_expires_at:
            raise OTPVerificationFailed(_("No completion code has been issued. Ask the customer to generate one."))
        if timezone.now() > booking.completion_otp_expires_at:
            raise OTPVerificationFailed(_("The completion code has expired. Ask the customer for a new one."))
        if booking.completion_otp_attempts >= settings.KAAMNOW["OTP_MAX_ATTEMPTS"]:
            raise OTPVerificationFailed(
                _("Too many incorrect attempts. Ask the customer for a new code."),
                status_code=http_status.HTTP_429_TOO_MANY_REQUESTS,
            )
        valid = hmac.compare_digest(booking.completion_otp_hash, _hash_otp(booking.pk, str(otp)))
        if valid:
            return _finalize_completion(booking, worker_user, "otp")
        booking.completion_otp_attempts += 1
        if booking.completion_otp_attempts >= settings.KAAMNOW["OTP_MAX_ATTEMPTS"]:
            booking.completion_otp_hash = ""  # burn the code
        booking.save(update_fields=["completion_otp_attempts", "completion_otp_hash", "updated_at"])
    # Raised outside the atomic block so the attempt counter is committed.
    remaining = max(settings.KAAMNOW["OTP_MAX_ATTEMPTS"] - booking.completion_otp_attempts, 0)
    raise OTPVerificationFailed(
        ngettext("Incorrect completion code. {n} attempt left.", "Incorrect completion code. {n} attempts left.", remaining).format(
            n=remaining
        )
    )


@transaction.atomic
def confirm_completion_by_customer(booking, customer_user):
    """Customer confirms completion in-app (they are the party the OTP protects)."""
    booking = Booking.objects.select_for_update().select_related("worker__user", "customer").get(pk=booking.pk)
    if booking.customer_id != customer_user.pk:
        raise BusinessRuleError(_("Only the customer can confirm completion."), status_code=403)
    if booking.status != Booking.Status.IN_PROGRESS:
        raise BusinessRuleError(_("Booking is not in progress."), status_code=http_status.HTTP_409_CONFLICT)
    return _finalize_completion(booking, customer_user, "customer_confirmation")


def auto_complete_at(booking):
    """When a job the worker marked finished completes on its own, or None."""
    if booking.status != Booking.Status.IN_PROGRESS or not booking.worker_finished_at:
        return None
    return booking.worker_finished_at + timedelta(hours=settings.KAAMNOW["JOB_AUTO_COMPLETE_HOURS"])


@transaction.atomic
def mark_worker_finished(booking, worker_user):
    """The worker says the work is done. The customer is asked to tap "Job completed". Calling it
    again re-sends the reminder (not more often than WORKER_FINISHED_REMIND_MINUTES) without
    moving the auto-complete time."""
    booking = Booking.objects.select_for_update().select_related("worker__user", "customer", "request").get(pk=booking.pk)
    if booking.worker.user_id != worker_user.pk:
        raise BusinessRuleError(_("Only the assigned worker can say the job is finished."), status_code=403)
    if booking.status != Booking.Status.IN_PROGRESS:
        raise BusinessRuleError(_("Booking is not in progress."), status_code=http_status.HTTP_409_CONFLICT)
    from django.core.cache import cache

    now = timezone.now()
    cache_key = f"worker-finished-remind:{booking.pk}"
    if cache.get(cache_key) is not None:
        raise BusinessRuleError(_("The customer was just reminded. Please wait a few minutes."),
                                status_code=http_status.HTTP_429_TOO_MANY_REQUESTS)
    cache.set(cache_key, now.isoformat(), settings.KAAMNOW["WORKER_FINISHED_REMIND_MINUTES"] * 60)
    if booking.worker_finished_at is None:
        booking.worker_finished_at = now
        booking.save(update_fields=["worker_finished_at", "updated_at"])
        _log(booking, booking.status, booking.status, worker_user, "Worker finished the work")
    notify(
        booking.customer, Notification.Type.BOOKING_STATUS, t("Is the job done?"),
        t("{name} says the work on \"{job}\" is finished. Open the booking and tap Job completed.",
          name=booking.worker.user.full_name, job=booking.request.title),
        {"booking_id": booking.pk},
    )
    return booking


@transaction.atomic
def customer_not_finished(booking, customer_user, reason):
    """The customer says the work is not finished yet. The worker is told why and carries on."""
    booking = Booking.objects.select_for_update().select_related("worker__user", "customer").get(pk=booking.pk)
    if booking.customer_id != customer_user.pk:
        raise BusinessRuleError(_("Only the customer can answer this."), status_code=403)
    if booking.status != Booking.Status.IN_PROGRESS or not booking.worker_finished_at:
        raise BusinessRuleError(_("The worker has not said the job is finished."),
                                status_code=http_status.HTTP_409_CONFLICT)
    booking.worker_finished_at = None
    booking.save(update_fields=["worker_finished_at", "updated_at"])
    from django.core.cache import cache

    cache.delete(f"worker-finished-remind:{booking.pk}")
    _log(booking, booking.status, booking.status, customer_user, f"Customer: not finished yet ({reason})"[:255])
    notify(
        booking.worker.user, Notification.Type.BOOKING_STATUS, t("Not finished yet"),
        t("The customer says the job is not finished yet: {reason}", reason=reason), {"booking_id": booking.pk},
    )
    return booking


def auto_complete_finished_jobs():
    """Completes jobs the worker marked finished when the customer did not answer in time, so the
    worker is free for new requests."""
    cutoff = timezone.now() - timedelta(hours=settings.KAAMNOW["JOB_AUTO_COMPLETE_HOURS"])
    done = 0
    for pk in Booking.objects.filter(status=Booking.Status.IN_PROGRESS, worker_finished_at__lte=cutoff).values_list(
            "pk", flat=True):
        with transaction.atomic():
            booking = Booking.objects.select_for_update().select_related("worker__user", "customer").get(pk=pk)
            if booking.status != Booking.Status.IN_PROGRESS or not booking.worker_finished_at \
                    or booking.worker_finished_at > cutoff:
                continue
            _finalize_completion(booking, None, "auto")
            done += 1
    return done


def expire_stale_requests():
    """Expires open requests whose preferred time passed long ago and closes their offers."""
    from apps.offers.models import WorkerOffer

    cutoff = timezone.now() - timedelta(hours=settings.KAAMNOW["REQUEST_EXPIRY_HOURS"])
    expired = 0
    for req_id in ServiceRequest.objects.filter(
        status=ServiceRequest.Status.OPEN, preferred_time__lt=cutoff
    ).values_list("id", flat=True):
        with transaction.atomic():
            req = ServiceRequest.objects.select_for_update().get(pk=req_id)
            if req.status != ServiceRequest.Status.OPEN:
                continue
            req.status = ServiceRequest.Status.EXPIRED
            req.save(update_fields=["status", "updated_at"])
            WorkerOffer.objects.filter(request=req, status=WorkerOffer.Status.PENDING).update(
                status=WorkerOffer.Status.CLOSED, updated_at=timezone.now()
            )
            expired += 1
    return expired
