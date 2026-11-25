from django.conf import settings
from django.db import models

from apps.common.utils import RandomUploadPath


class PortfolioPhoto(models.Model):
    """A photo of a worker's past work, shown on their public profile.

    Photos are re-encoded on upload: location and camera data (EXIF) are removed, because a
    photo taken in a customer's home can carry that home's GPS position.
    """

    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="portfolio")
    image = models.ImageField(upload_to=RandomUploadPath("workers/portfolio"))
    caption = models.CharField(max_length=150, blank=True)
    category = models.ForeignKey("catalog.ServiceCategory", on_delete=models.SET_NULL, null=True, blank=True,
                                 related_name="+")
    booking = models.ForeignKey(
        "jobs.Booking", on_delete=models.SET_NULL, null=True, blank=True, related_name="+",
        help_text="A finished KaamNow job this photo is from. Shown as 'From a KaamNow job'.",
    )
    position = models.PositiveSmallIntegerField(default=0)
    is_hidden = models.BooleanField(default=False, db_index=True, help_text="Hidden by an admin.")
    hidden_reason = models.CharField(max_length=255, blank=True)
    hidden_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                  related_name="+")
    hidden_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["position", "-created_at"]

    def __str__(self):
        return f"Photo {self.pk} of worker {self.worker_id}"
