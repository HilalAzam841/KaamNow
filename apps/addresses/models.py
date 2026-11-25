from decimal import Decimal

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import Q


class SavedAddress(models.Model):
    """A place a customer posts jobs from (Home, Work, or a named place). Only its owner sees it."""

    class Label(models.TextChoices):
        HOME = "home", "Home"
        WORK = "work", "Work"
        OTHER = "other", "Other"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="saved_addresses")
    label = models.CharField(max_length=5, choices=Label.choices)
    name = models.CharField(max_length=40, blank=True, help_text="For Other: e.g. \"Ammi's house\".")
    address = models.CharField(max_length=255)
    area = models.CharField(max_length=100, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6,
                                   validators=[MinValueValidator(Decimal("-90")), MaxValueValidator(Decimal("90"))])
    longitude = models.DecimalField(max_digits=9, decimal_places=6,
                                    validators=[MinValueValidator(Decimal("-180")), MaxValueValidator(Decimal("180"))])
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-is_default", "label", "created_at"]
        constraints = [
            models.UniqueConstraint(fields=["user"], condition=Q(is_default=True), name="one_default_address"),
            models.UniqueConstraint(fields=["user", "label"], condition=Q(label__in=["home", "work"]),
                                    name="one_home_one_work"),
        ]

    def __str__(self):
        return f"{self.get_label_display()} of user {self.user_id}"
