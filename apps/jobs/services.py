import hashlib
import hmac
import secrets
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import status as http_status

from apps.accounts.models import WorkerProfile
from apps.common.exceptions import BusinessRuleError
from apps.common.geo import bounding_box, get_geo_backend, haversine_km
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


def find_nearby_workers(category, latitude, longitude, exclude_user=None):
    qs = eligible_workers_queryset(category)
    if exclude_user is not None:
        qs = qs.exclude(user=exclude_user)
    return get_geo_backend().workers_covering_point(qs, latitude, longitude)


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
    if not worker.services.filter(category_id=service_request.category_id, is_active=True).exists():
        return False
    distance = worker_distance_to_request(worker, service_request)
    return distance is not None and distance <= float(worker.service_radius_km)


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
        .order_by("-created_at")
    )
    results = []
    for req in candidates:
        distance = worker_distance_to_request(worker, req)
        if distance is not None and distance <= float(worker.service_radius_km):
            req.distance_km = distance
            results.append(req)
    return results


# --------------------------------------------------------------------------
# Service requests
# --------------------------------------------------------------------------
@transaction.atomic
def create_service_request(customer, images=None, **data):
    category = data["category"]
    if not category.is_active:
        raise BusinessRuleError("This service category is not available.")
    service_request = ServiceRequest.objects.create(customer=customer, **data)
    for image in images or []:
        ServiceRequestImage.objects.create(request=service_request, image=image)

    workers = find_nearby_workers(category, service_request.latitude, service_request.longitude, exclude_user=customer)
    if workers:
        transaction.on_commit(lambda: notify_many(
            [w.user for w in workers], Notification.Type.NEW_REQUEST,
            f"New {category.name} request nearby",
            service_request.title,
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
            "Only open requests can be cancelled. Cancel the booking instead.", status_code=http_status.HTTP_409_CONFLICT
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
            "Request cancelled", f"The customer cancelled '{service_request.title}'.",
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
    BookingStatusLog.objects.create(
        booking=booking, from_status=from_status, to_status=to_status, changed_by=user, note=note
    )


@transaction.atomic
def update_booking_status(booking, worker_user, new_status, note=""):
    booking = Booking.objects.select_for_update().get(pk=booking.pk)
    if booking.worker.user_id != worker_user.pk:
        raise BusinessRuleError("Only the assigned worker can update this booking.", status_code=403)
    allowed = WORKER_TRANSITIONS.get(booking.status, set())
    if new_status not in allowed:
        raise BusinessRuleError(
            f"Cannot change status from '{booking.status}' to '{new_status}'.", status_code=http_status.HTTP_409_CONFLICT
        )
    old = booking.status
    booking.status = new_status
    setattr(booking, STATUS_TIMESTAMP[new_status], timezone.now())
    booking.save(update_fields=["status", STATUS_TIMESTAMP[new_status], "updated_at"])
    _log(booking, old, new_status, worker_user, note)
    notify(
        booking.customer, Notification.Type.BOOKING_STATUS, "Booking update",
        f"Your worker status: {booking.get_status_display()}.",
        {"booking_id": booking.pk, "status": new_status},
    )
    return booking


@transaction.atomic
def cancel_booking(booking, user, reason):
    booking = Booking.objects.select_for_update().select_related("request", "worker__user", "customer").get(pk=booking.pk)
    if booking.status not in (Booking.Status.CONFIRMED, Booking.Status.ON_THE_WAY, Booking.Status.ARRIVED):
        raise BusinessRuleError(
            "This booking can no longer be cancelled.", status_code=http_status.HTTP_409_CONFLICT
        )
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
    other = booking.worker.user if user.pk == booking.customer_id else booking.customer
    notify(
        other, Notification.Type.BOOKING_CANCELLED, "Booking cancelled",
        f"Booking #{booking.pk} was cancelled. Reason: {reason}", {"booking_id": booking.pk},
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
        raise BusinessRuleError("Only the customer can request the completion code.", status_code=403)
    if booking.status != Booking.Status.IN_PROGRESS:
        raise BusinessRuleError(
            "A completion code is available once work has started.", status_code=http_status.HTTP_409_CONFLICT
        )
    cfg = settings.KAAMNOW
    now = timezone.now()
    if booking.completion_otp_sent_at and (now - booking.completion_otp_sent_at).total_seconds() < cfg[
        "OTP_RESEND_COOLDOWN_SECONDS"
    ]:
        raise BusinessRuleError("Please wait before requesting a new code.", status_code=http_status.HTTP_429_TOO_MANY_REQUESTS)

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
    record_commission(booking)
    for recipient in (booking.customer, booking.worker.user):
        notify(
            recipient, Notification.Type.BOOKING_COMPLETED, "Job completed",
            f"Booking #{booking.pk} is complete. Amount: Rs. {booking.agreed_price}.", {"booking_id": booking.pk},
        )
    return booking


class OTPVerificationFailed(BusinessRuleError):
    default_code = "invalid_otp"


def complete_booking_with_otp(booking, worker_user, otp):
    """Worker submits the OTP the customer shared. Attempts are counted even on failure."""
    with transaction.atomic():
        booking = Booking.objects.select_for_update().select_related("worker__user", "customer").get(pk=booking.pk)
        if booking.worker.user_id != worker_user.pk:
            raise BusinessRuleError("Only the assigned worker can submit the completion code.", status_code=403)
        if booking.status != Booking.Status.IN_PROGRESS:
            raise BusinessRuleError("Booking is not in progress.", status_code=http_status.HTTP_409_CONFLICT)
        if not booking.completion_otp_hash or not booking.completion_otp_expires_at:
            raise OTPVerificationFailed("No completion code has been issued. Ask the customer to generate one.")
        if timezone.now() > booking.completion_otp_expires_at:
            raise OTPVerificationFailed("The completion code has expired. Ask the customer for a new one.")
        if booking.completion_otp_attempts >= settings.KAAMNOW["OTP_MAX_ATTEMPTS"]:
            raise OTPVerificationFailed(
                "Too many incorrect attempts. Ask the customer for a new code.",
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
    raise OTPVerificationFailed(f"Incorrect completion code. {remaining} attempt(s) left.")


@transaction.atomic
def confirm_completion_by_customer(booking, customer_user):
    """Customer confirms completion in-app (they are the party the OTP protects)."""
    booking = Booking.objects.select_for_update().select_related("worker__user", "customer").get(pk=booking.pk)
    if booking.customer_id != customer_user.pk:
        raise BusinessRuleError("Only the customer can confirm completion.", status_code=403)
    if booking.status != Booking.Status.IN_PROGRESS:
        raise BusinessRuleError("Booking is not in progress.", status_code=http_status.HTTP_409_CONFLICT)
    return _finalize_completion(booking, customer_user, "customer_confirmation")
