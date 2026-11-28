"""Before and after photos of a job.

- Only the booking's worker adds photos. "Before" photos once they have arrived (or started);
  "after" photos once work has started, and up to AFTER_WINDOW_HOURS after completion.
- At most MAX_PHOTOS_PER_KIND of each kind. The worker can delete their own photo while they
  could still add one of that kind.
- The customer is notified once, when the first "after" photo is added.
- Pictures are re-encoded (no location data) and stored privately.
"""

from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import t
from apps.jobs.models import Booking
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import MAX_PHOTOS_PER_KIND, JobPhoto

AFTER_WINDOW_HOURS = 24

BEFORE_STATUSES = (Booking.Status.ARRIVED, Booking.Status.IN_PROGRESS)


def can_add(booking, kind, now=None):
    now = now or timezone.now()
    if kind == JobPhoto.Kind.BEFORE:
        return booking.status in BEFORE_STATUSES
    if booking.status == Booking.Status.IN_PROGRESS:
        return True
    return (booking.status == Booking.Status.COMPLETED and booking.completed_at is not None
            and now <= booking.completed_at + timedelta(hours=AFTER_WINDOW_HOURS))


def summary(booking, user=None):
    """Counts per kind and what the given user may still add (for the booking screen)."""
    counts = {k: 0 for k in JobPhoto.Kind.values}
    for kind in booking.job_photos.values_list("kind", flat=True):
        counts[kind] += 1
    is_worker = user is not None and user.pk == booking.worker.user_id
    return {
        "before": counts[JobPhoto.Kind.BEFORE],
        "after": counts[JobPhoto.Kind.AFTER],
        "max_per_kind": MAX_PHOTOS_PER_KIND,
        "can_add_before": is_worker and can_add(booking, JobPhoto.Kind.BEFORE)
        and counts[JobPhoto.Kind.BEFORE] < MAX_PHOTOS_PER_KIND,
        "can_add_after": is_worker and can_add(booking, JobPhoto.Kind.AFTER)
        and counts[JobPhoto.Kind.AFTER] < MAX_PHOTOS_PER_KIND,
    }


def _require_worker(booking, user):
    if user.pk != booking.worker.user_id:
        raise BusinessRuleError(_("Only the worker on this job can add or remove job photos."), status_code=403)


def add_photo(booking, user, *, kind, image, caption=""):
    from apps.portfolio.services import clean_image

    _require_worker(booking, user)
    picture = clean_image(image)  # outside the lock: decoding can take a moment
    with transaction.atomic():
        booking = Booking.objects.select_for_update().select_related("customer", "worker__user").get(pk=booking.pk)
        if not can_add(booking, kind):
            if kind == JobPhoto.Kind.BEFORE:
                msg = _("Add before photos once you have arrived, before you finish the job.")
            else:
                msg = _("Add after photos once you have started work, up to 24 hours after the job is done.")
            raise BusinessRuleError(msg, code="job_photo_not_now", status_code=http_status.HTTP_409_CONFLICT)
        existing = JobPhoto.objects.filter(booking=booking, kind=kind)
        if existing.count() >= MAX_PHOTOS_PER_KIND:
            raise BusinessRuleError(_("You can add up to %(n)d photos of each kind.") % {"n": MAX_PHOTOS_PER_KIND},
                                    code="job_photo_limit", status_code=http_status.HTTP_409_CONFLICT)
        first_after = kind == JobPhoto.Kind.AFTER and not existing.exists()
        photo = JobPhoto(booking=booking, kind=kind, caption=(caption or "").strip()[:140], uploaded_by=user)
        photo.image.save(picture.name, picture, save=False)
        photo.save()
        if first_after:
            notify(
                booking.customer, Notification.Type.BOOKING_STATUS,
                t("{name} added photos of the finished work", name=user.full_name.split(" ")[0]),
                t("Open the booking to see the before and after photos."),
                {"booking_id": booking.pk},
            )
    return photo


def delete_photo(booking, user, photo):
    _require_worker(booking, user)
    if not can_add(booking, photo.kind):
        raise BusinessRuleError(_("This photo can no longer be removed."), code="job_photo_locked",
                                status_code=http_status.HTTP_409_CONFLICT)
    photo.image.delete(save=False)
    photo.delete()
