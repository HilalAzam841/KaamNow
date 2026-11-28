from django.conf import settings
from django.db import models

from apps.common.models import TimeStampedModel


class GuaranteeClaim(TimeStampedModel):
    """A customer asks the worker to fix a problem with a finished job, for free.

    pending   -> the worker accepts (with a time to come back) or declines (with a reason)
    accepted  -> the worker marks the redo done -> redo_done
    redo_done -> the customer confirms it is fixed -> fixed
    The customer can escalate to the KaamNow team when the worker declines, does not answer in
    time, or the redo did not fix it. Escalating opens a complaint that admins handle as usual.
    """

    class Status(models.TextChoices):
        PENDING = "pending", "Waiting for the worker"
        ACCEPTED = "accepted", "Worker will come back"
        DECLINED = "declined", "Worker declined"
        REDO_DONE = "redo_done", "Worker says it is fixed"
        FIXED = "fixed", "Customer confirmed it is fixed"
        ESCALATED = "escalated", "Sent to the KaamNow team"
        WITHDRAWN = "withdrawn", "Withdrawn by the customer"

    OPEN_STATUSES = (Status.PENDING, Status.ACCEPTED, Status.REDO_DONE)

    booking = models.OneToOneField("jobs.Booking", on_delete=models.CASCADE, related_name="guarantee_claim")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="guarantee_claims")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="guarantee_claims")
    problem = models.TextField(max_length=1000)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    redo_time = models.DateTimeField(null=True, blank=True, help_text="When the worker will come back.")
    worker_note = models.CharField(max_length=500, blank=True, help_text="The worker's reason or note.")
    respond_by = models.DateTimeField(help_text="The worker should answer by then; after it the customer can escalate.")
    accepted_at = models.DateTimeField(null=True, blank=True)
    redo_done_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    complaint = models.OneToOneField("support.Complaint", on_delete=models.SET_NULL, null=True, blank=True,
                                     related_name="guarantee_claim")

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Guarantee claim #{self.pk} on booking #{self.booking_id}"

    @property
    def is_open(self):
        return self.status in self.OPEN_STATUSES
