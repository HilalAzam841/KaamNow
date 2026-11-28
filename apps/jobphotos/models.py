from django.conf import settings
from django.db import models

from apps.common.storage import private_storage
from apps.common.utils import RandomUploadPath

MAX_PHOTOS_PER_KIND = 5


class JobPhoto(models.Model):
    """A photo the worker takes before starting or after finishing a job.

    The photos are taken inside the customer's home, so they are private: stored outside the
    public media folder and only streamed to the booking's customer and worker, or to an admin
    (each admin view is audited). Re-encoded on upload, so there is no location or camera data.
    """

    class Kind(models.TextChoices):
        BEFORE = "before", "Before work"
        AFTER = "after", "After work"

    booking = models.ForeignKey("jobs.Booking", on_delete=models.CASCADE, related_name="job_photos")
    kind = models.CharField(max_length=10, choices=Kind.choices)
    image = models.ImageField(storage=private_storage, upload_to=RandomUploadPath("job_photos"))
    caption = models.CharField(max_length=140, blank=True)
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
                                    related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]
        indexes = [models.Index(fields=["booking", "kind"])]

    def __str__(self):
        return f"{self.get_kind_display()} photo {self.pk} on booking {self.booking_id}"
