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

from .models import Review


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
