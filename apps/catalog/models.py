from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models
from django.utils.text import slugify

from apps.common.models import TimeStampedModel


class ServiceCategory(TimeStampedModel):
    name = models.CharField(max_length=100, unique=True)
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
