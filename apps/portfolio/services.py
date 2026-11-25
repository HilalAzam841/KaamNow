"""Worker portfolio: photos of past work on the public profile.

Every upload is checked (real JPEG/PNG/WEBP, size limit) and re-encoded: rotated upright,
shrunk to at most 1600 px, and saved without EXIF, so no GPS position or camera details leak.
Admins can hide a photo (the worker is told why); hidden photos are never shown publicly.
"""

import io

from django.core.files.base import ContentFile
from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from PIL import Image, ImageOps
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError
from apps.common.i18n import t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import PortfolioPhoto

MAX_PHOTOS = 12
MAX_SIDE = 1600


def clean_image(upload):
    """Returns a ContentFile with the picture only: upright, at most MAX_SIDE px, no metadata."""
    upload.seek(0)
    with Image.open(upload) as img:
        img = ImageOps.exif_transpose(img)
        has_alpha = img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info)
        img = img.convert("RGBA" if has_alpha else "RGB")
        img.thumbnail((MAX_SIDE, MAX_SIDE))
        out = io.BytesIO()
        if has_alpha:
            img.save(out, format="PNG", optimize=True)
            ext = "png"
        else:
            img.save(out, format="JPEG", quality=85, optimize=True)
            ext = "jpg"
    return ContentFile(out.getvalue(), name=f"photo.{ext}")


def visible_photos(worker):
    return PortfolioPhoto.objects.filter(worker=worker, is_hidden=False).select_related("category")


def _check_booking(worker, booking):
    from apps.jobs.models import Booking

    if booking is None:
        return
    if booking.worker_id != worker.pk or booking.status != Booking.Status.COMPLETED:
        raise BusinessRuleError(_("Link a job you finished on KaamNow."))


def _check_category(worker, category):
    if category is not None and not worker.services.filter(category=category).exists():
        raise BusinessRuleError(_("Choose one of the services you offer."))


@transaction.atomic
def add_photo(worker, image, *, caption="", category=None, booking=None):
    # Lock the worker row so two uploads at once cannot pass the limit.
    type(worker).objects.select_for_update().filter(pk=worker.pk).first()
    count = PortfolioPhoto.objects.filter(worker=worker).count()
    if count >= MAX_PHOTOS:
        raise BusinessRuleError(_("You can have up to 12 photos. Delete one first."),
                                status_code=http_status.HTTP_409_CONFLICT)
    _check_category(worker, category)
    _check_booking(worker, booking)
    if booking is not None and category is None:
        category = booking.request.category
    return PortfolioPhoto.objects.create(worker=worker, image=clean_image(image), caption=caption.strip(),
                                         category=category, booking=booking, position=count)


def update_photo(photo, data):
    if "category" in data:
        _check_category(photo.worker, data["category"])
    for key in ("caption", "category"):
        if key in data:
            setattr(photo, key, data[key].strip() if key == "caption" else data[key])
    photo.save(update_fields=[k for k in ("caption", "category") if k in data] or None)
    return photo


@transaction.atomic
def reorder(worker, ids):
    photos = {p.pk: p for p in PortfolioPhoto.objects.select_for_update().filter(worker=worker)}
    if sorted(ids) != sorted(photos):
        raise BusinessRuleError(_("Send every one of your photos, each once, in the new order."))
    for i, pk in enumerate(ids):
        if photos[pk].position != i:
            photos[pk].position = i
            photos[pk].save(update_fields=["position"])
    return [photos[pk] for pk in ids]


def delete_photo(photo):
    photo.image.delete(save=False)
    photo.delete()


def hide(photo, admin, reason):
    photo.is_hidden, photo.hidden_reason, photo.hidden_by, photo.hidden_at = True, reason, admin, timezone.now()
    photo.save(update_fields=["is_hidden", "hidden_reason", "hidden_by", "hidden_at"])
    notify(photo.worker.user, Notification.Type.SYSTEM, t("A portfolio photo was hidden"),
           t("KaamNow hid one of your work photos: {reason}", reason=reason), {"portfolio_photo_id": photo.pk})
    return photo


def unhide(photo, admin):
    photo.is_hidden, photo.hidden_reason, photo.hidden_by, photo.hidden_at = False, "", admin, timezone.now()
    photo.save(update_fields=["is_hidden", "hidden_reason", "hidden_by", "hidden_at"])
    return photo
