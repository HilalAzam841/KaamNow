from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models
from django.utils.text import slugify
from django.utils.translation import get_language

from apps.common.models import TimeStampedModel


class ServiceCategory(TimeStampedModel):
    name = models.CharField(max_length=100, unique=True)
    name_ur = models.CharField("Urdu name", max_length=100, blank=True, help_text="Shown to users who picked Urdu.")
    slug = models.SlugField(max_length=110, unique=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=100, blank=True, help_text="Icon key used by the mobile app.")
    is_active = models.BooleanField(default=True, db_index=True)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name_plural = "service categories"

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

    @property
    def display_name(self):
        """The name in the language of the current request (Urdu when set and asked for)."""
        if self.name_ur and (get_language() or "").startswith("ur"):
            return self.name_ur
        return self.name


class WorkerService(TimeStampedModel):
    """A category a worker offers, with optional description and starting price."""

    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="services")
    category = models.ForeignKey(ServiceCategory, on_delete=models.PROTECT, related_name="worker_services")
    description = models.TextField(blank=True, max_length=1000)
    starting_price = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(Decimal("0"))]
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["category__sort_order", "category__name"]
        constraints = [
            models.UniqueConstraint(fields=["worker", "category"], name="unique_worker_service_category"),
        ]
        indexes = [models.Index(fields=["category", "is_active"])]

    def __str__(self):
        return f"{self.worker} - {self.category}"
