from django.conf import settings
from django.db import models

from apps.common.models import TimeStampedModel


class Complaint(TimeStampedModel):
    class Category(models.TextChoices):
        SERVICE_QUALITY = "service_quality", "Poor service quality"
        NO_SHOW = "no_show", "Worker did not arrive"
        OVERCHARGING = "overcharging", "Overcharging"
        BEHAVIOUR = "behaviour", "Rude or unsafe behaviour"
        PAYMENT = "payment", "Payment issue"
        DAMAGE = "damage", "Property damage"
        FRAUD = "fraud", "Fraud"
        APP_ISSUE = "app_issue", "App problem"
        GUARANTEE = "guarantee", "Work guarantee claim"
        OTHER = "other", "Other"

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        IN_REVIEW = "in_review", "In review"
        RESOLVED = "resolved", "Resolved"
        REJECTED = "rejected", "Rejected"

    raised_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="complaints")
    against_user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="complaints_against"
    )
    booking = models.ForeignKey(
        "jobs.Booking", on_delete=models.SET_NULL, null=True, blank=True, related_name="complaints"
    )
    category = models.CharField(max_length=20, choices=Category.choices)
    subject = models.CharField(max_length=150)
    description = models.TextField(max_length=3000)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN, db_index=True)
    resolution = models.TextField(blank=True, max_length=3000)
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["status", "category"])]

    def __str__(self):
        return f"Complaint #{self.pk}: {self.subject}"
