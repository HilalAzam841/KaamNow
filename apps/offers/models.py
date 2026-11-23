from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.common.models import TimeStampedModel


class Party(models.TextChoices):
    CUSTOMER = "customer", "Customer"
    WORKER = "worker", "Worker"


class WorkerOffer(TimeStampedModel):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACCEPTED = "accepted", "Accepted"
        REJECTED = "rejected", "Rejected by customer"
        WITHDRAWN = "withdrawn", "Withdrawn by worker"
        CLOSED = "closed", "Closed"

    request = models.ForeignKey("jobs.ServiceRequest", on_delete=models.CASCADE, related_name="offers")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="offers")
    initial_price = models.DecimalField(max_digits=10, decimal_places=2)
    current_price = models.DecimalField(
        max_digits=10, decimal_places=2, help_text="Latest price on the table in the negotiation."
    )
    awaiting = models.CharField(
        max_length=10, choices=Party.choices, default=Party.CUSTOMER,
        help_text="Which party must respond next.",
    )
    estimated_arrival_minutes = models.PositiveSmallIntegerField()
    message = models.CharField(max_length=500, blank=True)
    additional_info = models.TextField(blank=True, max_length=1000)
    distance_km = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)

    class Meta:
        ordering = ["current_price", "created_at"]
        constraints = [
            # One offer per worker per request: blocks duplicate bids.
            models.UniqueConstraint(fields=["request", "worker"], name="unique_offer_per_worker_request"),
            models.CheckConstraint(condition=Q(current_price__gt=0), name="offer_price_positive"),
        ]
        indexes = [models.Index(fields=["request", "status"])]

    def __str__(self):
        return f"Offer #{self.pk} Rs.{self.current_price} on request #{self.request_id}"

    @property
    def is_pending(self):
        return self.status == self.Status.PENDING


class Negotiation(models.Model):
    """Immutable history entry for every price move on an offer."""

    class Action(models.TextChoices):
        OFFER = "offer", "Initial offer"
        REVISE = "revise", "Worker revised offer"
        COUNTER = "counter", "Counter proposal"
        AGREE = "agree", "Agreed to price"
        ACCEPT = "accept", "Customer accepted (booking created)"
        REJECT = "reject", "Rejected"
        WITHDRAW = "withdraw", "Withdrawn"

    offer = models.ForeignKey(WorkerOffer, on_delete=models.CASCADE, related_name="negotiations")
    party = models.CharField(max_length=10, choices=Party.choices)
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    action = models.CharField(max_length=10, choices=Action.choices)
    amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    message = models.CharField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self):
        return f"{self.party} {self.action} {self.amount}"
