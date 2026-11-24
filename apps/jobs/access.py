from django.http import Http404
from django.shortcuts import get_object_or_404

from .models import Booking


def booking_for_participant(user, booking_id, queryset=None):
    """Returns the booking if `user` is its customer or worker, otherwise 404 (ids cannot be probed)."""
    qs = queryset if queryset is not None else Booking.objects.select_related("worker__user", "customer", "request")
    booking = get_object_or_404(qs, pk=booking_id)
    if user.pk not in (booking.customer_id, booking.worker.user_id):
        raise Http404
    return booking
