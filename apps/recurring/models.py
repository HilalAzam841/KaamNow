from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.models import TimeStampedModel


class RecurringJob(TimeStampedModel):
    """A job that repeats (weekly, every two weeks or monthly), normally with the same worker.

    Two days before each visit a book-again request is created for the worker. If the worker
    cannot take it then, the request goes to every free worker nearby instead.
    """

    class Frequency(models.TextChoices):
        WEEKLY = "weekly", "Every week"
        BIWEEKLY = "biweekly", "Every two weeks"
        MONTHLY = "monthly", "Every month"

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        PAUSED = "paused", "Paused"
        CANCELLED = "cancelled", "Cancelled"

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="recurring_jobs")
    worker = models.ForeignKey(
        "accounts.WorkerProfile", on_delete=models.SET_NULL, null=True, blank=True, related_name="recurring_jobs",
        help_text="Empty when the worker left: each visit then goes to every free worker nearby.",
    )
    category = models.ForeignKey("catalog.ServiceCategory", on_delete=models.PROTECT, related_name="+")
    title = models.CharField(max_length=150)
    description = models.TextField(max_length=3000)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    address = models.CharField(max_length=255)
    area = models.CharField(max_length=100, blank=True)
    duration_minutes = models.PositiveSmallIntegerField(
        default=120, validators=[MinValueValidator(30), MaxValueValidator(480)])
    budget = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    frequency = models.CharField(max_length=10, choices=Frequency.choices)
    next_visit = models.DateTimeField(db_index=True, help_text="When the next visit starts.")
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE, db_index=True)
    source_booking = models.ForeignKey(
        "jobs.Booking", on_delete=models.SET_NULL, null=True, blank=True, related_name="+")

    class Meta:
        ordering = ["next_visit"]

    def __str__(self):
        return f"{self.title} ({self.get_frequency_display()})"


class RecurringVisit(models.Model):
    """One visit of a recurring job and the request created for it."""

    class Outcome(models.TextChoices):
        SENT_TO_WORKER = "worker", "Sent to the usual worker"
        SENT_TO_ALL = "all", "Sent to every worker nearby"
        FAILED = "failed", "Could not be created"

    plan = models.ForeignKey(RecurringJob, on_delete=models.CASCADE, related_name="visits")
    scheduled_for = models.DateTimeField()
    request = models.OneToOneField("jobs.ServiceRequest", on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="recurring_visit")
    outcome = models.CharField(max_length=6, choices=Outcome.choices)
    note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-scheduled_for"]
        constraints = [models.UniqueConstraint(fields=["plan", "scheduled_for"], name="one_visit_per_time")]
