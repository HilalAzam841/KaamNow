from django.db.models import Max

from apps.accounts.models import WorkerProfile

from .models import FavouriteWorker

MAX_FAVOURITES = 100
MAX_RECENT = 20


def public_workers():
    return WorkerProfile.objects.select_related("user").prefetch_related("services__category", "working_hours").filter(
        verification_status=WorkerProfile.VerificationStatus.VERIFIED, user__is_active=True, user__is_suspended=False
    )


def favourite_ids(user):
    if not user.is_authenticated:
        return set()
    return set(FavouriteWorker.objects.filter(customer=user).values_list("worker_id", flat=True))


def favourites(user):
    """Saved workers that can still be booked, newest first, with when they were saved."""
    saved = {f.worker_id: f.created_at for f in FavouriteWorker.objects.filter(customer=user)}
    workers = list(public_workers().filter(pk__in=saved))
    for w in workers:
        w.saved_at = saved[w.pk]
    workers.sort(key=lambda w: w.saved_at, reverse=True)
    return workers


def recent_workers(user):
    """Workers who completed a job for this customer, most recent first."""
    from apps.jobs.models import Booking

    last = dict(
        Booking.objects.filter(customer=user, status=Booking.Status.COMPLETED)
        .values("worker_id").annotate(last=Max("completed_at")).order_by("-last").values_list("worker_id", "last")[
            :MAX_RECENT]
    )
    workers = list(public_workers().filter(pk__in=last))
    for w in workers:
        w.last_booked_at = last[w.pk]
    workers.sort(key=lambda w: w.last_booked_at or w.created_at, reverse=True)
    return workers
