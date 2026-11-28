from django.utils.translation import gettext as _
from decimal import ROUND_HALF_UP, Decimal

from django.db import IntegrityError, transaction
from django.db.models import Avg, Count

from apps.accounts.models import WorkerProfile
from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.jobs.models import Booking
from apps.common.i18n import t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import MAX_REVIEW_PHOTOS, Review, ReviewPhoto


def refresh_worker_rating(worker_id):
    stats = Review.objects.filter(worker_id=worker_id, is_visible=True).aggregate(avg=Avg("rating"), n=Count("id"))
    avg = Decimal(stats["avg"] or 0).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    WorkerProfile.objects.filter(pk=worker_id).update(average_rating=avg, rating_count=stats["n"])
    from apps.levels.services import refresh as refresh_level

    refresh_level(worker_id)


@transaction.atomic
def create_review(customer, booking, rating, comment=""):
    booking = Booking.objects.select_for_update().select_related("worker__user").get(pk=booking.pk)
    if booking.customer_id != customer.pk:
        raise BusinessRuleError(_("You can only review your own bookings."), status_code=403)
    if booking.status != Booking.Status.COMPLETED:
        raise ConflictError(_("You can review a worker only after the job is completed."))
    if Review.objects.filter(booking=booking).exists():
        raise ConflictError(_("You have already reviewed this booking."))
    try:
        with transaction.atomic():
            review = Review.objects.create(
                booking=booking, customer=customer, worker=booking.worker, rating=rating, comment=comment
            )
    except IntegrityError as exc:
        raise ConflictError(_("You have already reviewed this booking.")) from exc
    refresh_worker_rating(booking.worker_id)
    notify(
        booking.worker.user, Notification.Type.REVIEW, t("New review"),
        t("You received a {rating}-star review.", rating=rating), {"booking_id": booking.pk, "review_id": review.pk},
    )
    return review


def _lock_own_review(review, customer):
    review = Review.objects.select_for_update().get(pk=review.pk)
    if review.customer_id != customer.pk:
        raise BusinessRuleError(_("You can only change your own review."), status_code=403)
    return review


@transaction.atomic
def add_photo(review, customer, image):
    """Adds a photo to the customer's own review (up to MAX_REVIEW_PHOTOS). Location data is removed."""
    from apps.portfolio.services import clean_image

    review = _lock_own_review(review, customer)
    count = review.photos.count()
    if count >= MAX_REVIEW_PHOTOS:
        raise ConflictError(_("A review can have up to {n} photos.").format(n=MAX_REVIEW_PHOTOS),
                            code="too_many_photos")
    return ReviewPhoto.objects.create(review=review, image=clean_image(image), position=count)


@transaction.atomic
def delete_photo(photo, customer):
    _lock_own_review(photo.review, customer)
    photo.image.delete(save=False)
    photo.delete()


@transaction.atomic
def reply(review, worker_user, text):
    """The worker answers a review in public, once."""
    from django.utils import timezone

    review = Review.objects.select_for_update().select_related("worker__user", "customer").get(pk=review.pk)
    if review.worker.user_id != worker_user.pk:
        raise BusinessRuleError(_("Only the reviewed worker can reply."), status_code=403)
    if not review.is_visible:
        raise ConflictError(_("This review is hidden."))
    if review.reply:
        raise ConflictError(_("You have already replied to this review."), code="already_replied")
    text = (text or "").strip()
    if len(text) < 2:
        raise BusinessRuleError(_("Write a short reply."))
    review.reply, review.replied_at = text, timezone.now()
    review.save(update_fields=["reply", "replied_at", "updated_at"])
    notify(
        review.customer, Notification.Type.REVIEW, t("The worker replied to your review"),
        t("{name} replied to your review.", name=review.worker.user.full_name.split(" ")[0]),
        {"booking_id": review.booking_id, "review_id": review.pk, "worker_id": review.worker_id},
    )
    return review


def set_visible(review, visible):
    review.is_visible = visible
    review.save(update_fields=["is_visible", "updated_at"])
    refresh_worker_rating(review.worker_id)
    return review


def remove_reply(review):
    review.reply, review.replied_at = "", None
    review.save(update_fields=["reply", "replied_at", "updated_at"])
    return review


def set_photo_hidden(photo, admin, hidden, reason=""):
    photo.is_hidden = hidden
    photo.hidden_reason = reason if hidden else ""
    photo.hidden_by = admin if hidden else None
    photo.save(update_fields=["is_hidden", "hidden_reason", "hidden_by"])
    return photo
