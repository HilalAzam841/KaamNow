from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.models import TimeStampedModel


class Review(TimeStampedModel):
    booking = models.OneToOneField("jobs.Booking", on_delete=models.CASCADE, related_name="review")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews_given")
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True, max_length=1000)
    is_visible = models.BooleanField(default=True, help_text="Admins can hide abusive reviews.")

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["worker", "is_visible"])]
        constraints = [
            models.CheckConstraint(condition=models.Q(rating__gte=1, rating__lte=5), name="review_rating_1_to_5"),
        ]

    def __str__(self):
        return f"{self.rating}/5 for {self.worker}"
