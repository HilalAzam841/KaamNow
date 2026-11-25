"""Safety: SOS alerts during a job, emergency contacts, and trip-sharing links.

SOS: the customer or the worker presses SOS on an active job (or up to an hour after it ended).
Admins are alerted at once, and the person's emergency contacts get an SMS with a link to follow
the job. The other side of the booking is NOT told, so pressing SOS never escalates a situation.

Trip sharing: a private link (only its hash is stored) that shows the job's status and, while the
worker is on the way, the worker's position. It never shows phone numbers or the address, expires
a few hours after the job, and can be turned off at any time.
"""

import hashlib
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone, translation
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.common import sms
from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import t
from apps.notifications.models import Notification
from apps.notifications.services import notify_many

from .models import EmergencyContact, SosAlert, TripShare

logger = logging.getLogger(__name__)
MAX_CONTACTS = 3
SOS_AFTER_COMPLETION = timedelta(hours=1)
SHARE_AFTER_JOB = timedelta(hours=3)


# ---- emergency contacts ------------------------------------------------------
def add_contact(user, name, phone):
    if EmergencyContact.objects.filter(user=user, phone=phone).exists():
        raise BusinessRuleError(_("This number is already one of your emergency contacts."),
                                status_code=http_status.HTTP_409_CONFLICT)
    if phone == user.phone:
        raise BusinessRuleError(_("Add someone else's number, not your own."))
    if EmergencyContact.objects.filter(user=user).count() >= MAX_CONTACTS:
        raise BusinessRuleError(_("You can add up to 3 emergency contacts. Remove one first."))
    return EmergencyContact.objects.create(user=user, name=name.strip(), phone=phone)


# ---- trip sharing --------------------------------------------------------------
def _hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


def share_url(token):
    return settings.TRIP_SHARE_URL.format(token=token)


def active_share(booking, user):
    return TripShare.objects.filter(booking=booking, created_by=user, revoked_at__isnull=True,
                                    expires_at__gt=timezone.now()).first()


def _share_expiry(booking):
    _start, end = booking.request.window
    return max(end, timezone.now()) + SHARE_AFTER_JOB


def _new_share(booking, user):
    """Replaces the user's link for this booking with a new one. Returns (share, token)."""
    now = timezone.now()
    TripShare.objects.filter(booking=booking, created_by=user, revoked_at__isnull=True).update(revoked_at=now)
    token = secrets.token_urlsafe(24)
    share = TripShare.objects.create(booking=booking, created_by=user, token_hash=_hash(token),
                                     expires_at=_share_expiry(booking))
    return share, token


def _text_contacts(user, make_text):
    """Texts each emergency contact in the user's language. Returns how many were sent."""
    if not sms.is_available():
        return 0
    sent = 0
    with translation.override(user.language or "en"):
        text = make_text()
    for contact in EmergencyContact.objects.filter(user=user):
        try:
            sms.send(contact.phone, text)
            sent += 1
        except sms.SmsError:
            logger.exception("Safety SMS to an emergency contact failed (user %s)", user.pk)
    return sent


@transaction.atomic
def start_sharing(booking, user, *, send_to_contacts=False):
    if not booking.is_active:
        raise BusinessRuleError(_("A job can only be shared while it is booked or under way."),
                                status_code=http_status.HTTP_409_CONFLICT)
    share, token = _new_share(booking, user)
    url = share_url(token)
    texted = 0
    if send_to_contacts:
        if not EmergencyContact.objects.filter(user=user).exists():
            raise BusinessRuleError(_("Add an emergency contact first."))
        first = user.full_name.split(" ")[0]
        texted = _text_contacts(user, lambda: _("KaamNow: {name} shared a job with you. Follow it here: {url}").format(
            name=first, url=url))
    return share, url, texted


def stop_sharing(booking, user):
    return TripShare.objects.filter(booking=booking, created_by=user, revoked_at__isnull=True).update(
        revoked_at=timezone.now())


def shared_job(token):
    """What someone with the link sees, or None when the link is wrong, turned off or expired."""
    from apps.tracking.models import BookingLocation

    share = TripShare.objects.select_related(
        "booking__request__category", "booking__worker__user", "booking__customer", "created_by").filter(
        token_hash=_hash(token or "")).first()
    if share is None or share.revoked_at is not None or share.expires_at <= timezone.now():
        return None
    b = share.booking
    worker = b.worker
    location = None
    if b.status == b.Status.ON_THE_WAY:
        point = BookingLocation.objects.filter(booking=b).first()
        if point is not None:
            location = {"latitude": str(point.latitude), "longitude": str(point.longitude),
                        "recorded_at": point.recorded_at}
    return {
        "title": b.request.title,
        "category_name": b.request.category.display_name,
        "area": b.request.area,
        "status": b.status,
        "preferred_time": b.request.preferred_time,
        "duration_minutes": b.request.duration_minutes,
        "shared_by": "worker" if share.created_by_id == worker.user_id else "customer",
        "customer_name": b.customer.full_name.split(" ")[0],
        "worker": {
            "name": worker.user.full_name.split(" ")[0],
            "is_verified": worker.is_verified,
            "average_rating": str(worker.average_rating),
            "completed_jobs_count": worker.completed_jobs_count,
        },
        "on_the_way_at": b.on_the_way_at,
        "arrived_at": b.arrived_at,
        "started_at": b.started_at,
        "completed_at": b.completed_at,
        "worker_location": location,
        "expires_at": share.expires_at,
    }


# ---- SOS -------------------------------------------------------------------------
def can_raise_sos(booking):
    if booking.is_active:
        return True
    return (booking.status == booking.Status.COMPLETED and booking.completed_at is not None
            and booking.completed_at > timezone.now() - SOS_AFTER_COMPLETION)


def open_alert(booking, user):
    return SosAlert.objects.filter(booking=booking, raised_by=user).exclude(status=SosAlert.Status.RESOLVED).first()


@transaction.atomic
def raise_sos(booking, user, *, latitude=None, longitude=None, note=""):
    """Returns (alert, created). Pressing again while an alert is open returns the same alert."""
    from apps.tracking.models import BookingLocation

    if not can_raise_sos(booking):
        raise BusinessRuleError(_("SOS is only available during a job. If you are in danger, call 15."),
                                status_code=http_status.HTTP_409_CONFLICT)
    existing = open_alert(booking, user)
    if existing is not None:
        return existing, False
    is_worker = booking.worker.user_id == user.pk
    if latitude is None and is_worker:
        point = BookingLocation.objects.filter(booking=booking).first()
        if point is not None:
            latitude, longitude = point.latitude, point.longitude
    alert = SosAlert.objects.create(
        booking=booking, raised_by=user, role=SosAlert.Role.WORKER if is_worker else SosAlert.Role.CUSTOMER,
        latitude=latitude, longitude=longitude, note=note)

    admins = list(get_user_model().objects.filter(is_staff=True, is_active=True))
    if admins:
        transaction.on_commit(lambda: notify_many(
            admins, Notification.Type.SAFETY,
            t("SOS: {name} needs help", name=user.full_name),
            t("Booking #{id}, {title}. Call them now.", id=booking.pk, title=booking.request.title),
            {"sos_id": alert.pk, "booking_id": booking.pk}))

    if booking.is_active:
        _share, token = _new_share(booking, user)
        url = share_url(token)
    else:
        url = ""
    first = user.full_name.split(" ")[0]

    def text():
        msg = _("KaamNow SOS: {name} pressed the help button during a job. Please call them now on {phone}.").format(
            name=first, phone=user.phone)
        return f"{msg} {url}".strip()

    alert.contacts_texted = _text_contacts(user, text)
    alert.save(update_fields=["contacts_texted"])
    return alert, True


def handle_sos(alert, admin, *, status, note=""):
    if alert.status == SosAlert.Status.RESOLVED:
        raise BusinessRuleError(_("This alert is already resolved."), status_code=http_status.HTTP_409_CONFLICT)
    alert.status = status
    alert.handled_by = admin
    alert.handled_at = timezone.now()
    if note:
        alert.admin_note = note
    alert.save(update_fields=["status", "handled_by", "handled_at", "admin_note"])
    if status == SosAlert.Status.ACKNOWLEDGED:
        notify_many([alert.raised_by], Notification.Type.SAFETY, t("KaamNow has seen your SOS"),
                    t("Our team is on it and will call you. If you are in danger, call 15."),
                    {"booking_id": alert.booking_id, "sos_id": alert.pk})
    return alert
