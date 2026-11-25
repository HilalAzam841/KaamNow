from django.conf import settings
from django.db import models


class FavouriteWorker(models.Model):
    """A worker a customer saved to book again."""

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favourite_workers")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="favourited_by")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.UniqueConstraint(fields=["customer", "worker"], name="one_favourite_per_worker")]

    def __str__(self):
        return f"{self.customer} ♥ {self.worker}"
