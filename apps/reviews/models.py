from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.models import TimeStampedModel
from apps.common.utils import RandomUploadPath

MAX_REVIEW_PHOTOS = 3
MAX_REPLY = 500


class Review(TimeStampedModel):
    booking = models.OneToOneField("jobs.Booking", on_delete=models.CASCADE, related_name="review")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews_given")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True, max_length=1000)
    is_visible = models.BooleanField(default=True, help_text="Admins can hide abusive reviews.")
    reply = models.TextField(blank=True, max_length=MAX_REPLY, help_text="The worker's public reply (one per review).")
    replied_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["worker", "is_visible"])]
        constraints = [
            models.CheckConstraint(condition=models.Q(rating__gte=1, rating__lte=5), name="review_rating_1_to_5"),
        ]

    def __str__(self):
        return f"{self.rating}/5 for {self.worker}"


class ReviewPhoto(models.Model):
    """A photo the customer added to their review. Re-encoded on upload, so no location or camera data."""

    review = models.ForeignKey(Review, on_delete=models.CASCADE, related_name="photos")
    image = models.ImageField(upload_to=RandomUploadPath("reviews/photos"))
    position = models.PositiveSmallIntegerField(default=0)
    is_hidden = models.BooleanField(default=False, db_index=True, help_text="Hidden by an admin.")
    hidden_reason = models.CharField(max_length=255, blank=True)
    hidden_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                  related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["position", "created_at"]

    def __str__(self):
        return f"Photo {self.pk} on review {self.review_id}"
