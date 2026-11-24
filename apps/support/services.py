from django.utils.translation import gettext as _, gettext_noop
from django.db import transaction
from django.utils import timezone

from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.common.i18n import t
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
            raise BusinessRuleError(_("You can only report problems with your own bookings."), status_code=403)
        against = booking.worker.user if user.pk == booking.customer_id else booking.customer
        if Complaint.objects.filter(raised_by=user, booking=booking,
                                    status__in=[Complaint.Status.OPEN, Complaint.Status.IN_REVIEW]).exists():
            raise ConflictError(_("You already have an open complaint for this booking."))
    complaint = Complaint.objects.create(
        raised_by=user, against_user=against, booking=booking, category=category, subject=subject.strip(),
        description=description.strip(),
    )
    notify(user, Notification.Type.COMPLAINT, t("Complaint received"),
           t("We received your complaint #{id}. Our team will review it.", id=complaint.pk), {"complaint_id": complaint.pk})
    return complaint


COMPLAINT_TITLES = {
    Complaint.Status.IN_REVIEW: gettext_noop("Complaint #{id} in review"),
    Complaint.Status.RESOLVED: gettext_noop("Complaint #{id} resolved"),
    Complaint.Status.REJECTED: gettext_noop("Complaint #{id} closed"),
    Complaint.Status.OPEN: gettext_noop("Complaint #{id} reopened"),
}
COMPLAINT_BODIES = {
    Complaint.Status.IN_REVIEW: gettext_noop("Our team is looking into your complaint."),
    Complaint.Status.RESOLVED: gettext_noop("Your complaint has been resolved."),
    Complaint.Status.REJECTED: gettext_noop("Your complaint has been closed."),
    Complaint.Status.OPEN: gettext_noop("Your complaint is open again."),
}


@transaction.atomic
def update_complaint_status(complaint, admin_user, new_status, resolution="", request=None):
    complaint = Complaint.objects.select_for_update().get(pk=complaint.pk)
    if new_status not in TRANSITIONS.get(complaint.status, set()):
        raise ConflictError(f"Cannot move a complaint from '{complaint.status}' to '{new_status}'.")
    if new_status in (Complaint.Status.RESOLVED, Complaint.Status.REJECTED) and not resolution.strip():
        raise BusinessRuleError(_("A resolution note is required."))
    old = complaint.status
    complaint.status = new_status
    if resolution:
        complaint.resolution = resolution.strip()
    if new_status in (Complaint.Status.RESOLVED, Complaint.Status.REJECTED):
        complaint.resolved_by = admin_user
        complaint.resolved_at = timezone.now()
    complaint.save()
    audit(admin_user, AuditLog.Action.COMPLAINT_UPDATED, complaint, request, old=old, new=new_status)
    notify(complaint.raised_by, Notification.Type.COMPLAINT, t(COMPLAINT_TITLES[new_status], id=complaint.pk),
           complaint.resolution or t(COMPLAINT_BODIES[new_status]),
           {"complaint_id": complaint.pk, "status": new_status})
    return complaint
