from django.conf import settings
from django.db import models


class AuditLog(models.Model):
    """Append-only record of sensitive administrator actions."""

    class Action(models.TextChoices):
        WORKER_VERIFIED = "worker_verified", "Worker verified"
        WORKER_REJECTED = "worker_rejected", "Worker rejected"
        DOCUMENT_VIEWED = "document_viewed", "Worker document viewed"
        USER_SUSPENDED = "user_suspended", "User suspended"
        USER_REACTIVATED = "user_reactivated", "User reactivated"
        COMMISSION_CHANGED = "commission_changed", "Commission rate changed"
        CATEGORY_CHANGED = "category_changed", "Service category changed"
        SETTINGS_CHANGED = "settings_changed", "Platform settings changed"
        PLAN_CHANGED = "plan_changed", "Subscription or featured plan changed"
        SUBSCRIPTION_ACTIVATED = "subscription_activated", "Subscription activated manually"
        FEATURED_CANCELLED = "featured_cancelled", "Featured listing cancelled"
        COMPLAINT_UPDATED = "complaint_updated", "Complaint status changed"
        PAYMENT_DISPUTED = "payment_disputed", "Payment flagged as disputed"
        PAYOUT_PAID = "payout_paid", "Worker payout marked as paid"
        PAYOUT_REJECTED = "payout_rejected", "Worker payout rejected"
        COMMISSION_COLLECTED = "commission_collected", "Cash commission received from worker"

    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="audit_logs")
    action = models.CharField(max_length=30, choices=Action.choices, db_index=True)
    target_type = models.CharField(max_length=50)
    target_id = models.CharField(max_length=50)
    metadata = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.action} by {self.actor_id} on {self.target_type}#{self.target_id}"
