from django.db import transaction
from django.utils import timezone

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import Complaint

TRANSITIONS = {
    Complaint.Status.OPEN: {Complaint.Status.IN_REVIEW, Complaint.Status.RESOLVED, Complaint.Status.REJECTED},
    Complaint.Status.IN_REVIEW: {Complaint.Status.RESOLVED, Complaint.Status.REJECTED},
}


def create_complaint(user, *, category, subject, description, booking=None):
    against = None
    if booking is not None:
        if user.pk not in (booking.customer_id, booking.worker.user_id):
            raise BusinessRuleError("You can only report problems with your own bookings.", status_code=403)
        against = booking.worker.user if user.pk == booking.customer_id else booking.customer
        if Complaint.objects.filter(raised_by=user, booking=booking,
                                    status__in=[Complaint.Status.OPEN, Complaint.Status.IN_REVIEW]).exists():
            raise ConflictError("You already have an open complaint for this booking.")
    complaint = Complaint.objects.create(
        raised_by=user, against_user=against, booking=booking, category=category, subject=subject.strip(),
        description=description.strip(),
    )
    notify(user, Notification.Type.COMPLAINT, "Complaint received",
           f"We received your complaint #{complaint.pk}. Our team will review it.", {"complaint_id": complaint.pk})
    return complaint


@transaction.atomic
def update_complaint_status(complaint, admin_user, new_status, resolution="", request=None):
    complaint = Complaint.objects.select_for_update().get(pk=complaint.pk)
    if new_status not in TRANSITIONS.get(complaint.status, set()):
        raise ConflictError(f"Cannot move a complaint from '{complaint.status}' to '{new_status}'.")
    if new_status in (Complaint.Status.RESOLVED, Complaint.Status.REJECTED) and not resolution.strip():
        raise BusinessRuleError("A resolution note is required.")
    old = complaint.status
    complaint.status = new_status
    if resolution:
        complaint.resolution = resolution.strip()
    if new_status in (Complaint.Status.RESOLVED, Complaint.Status.REJECTED):
        complaint.resolved_by = admin_user
        complaint.resolved_at = timezone.now()
    complaint.save()
    audit(admin_user, AuditLog.Action.COMPLAINT_UPDATED, complaint, request, old=old, new=new_status)
    notify(complaint.raised_by, Notification.Type.COMPLAINT, f"Complaint #{complaint.pk} {complaint.get_status_display()}",
           complaint.resolution or f"Your complaint is now {complaint.get_status_display().lower()}.",
           {"complaint_id": complaint.pk, "status": new_status})
    return complaint
