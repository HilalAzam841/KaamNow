from django.contrib import admin

from .models import Review
from .services import refresh_worker_rating


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ["booking", "worker", "customer", "rating", "is_visible", "created_at"]
    list_filter = ["rating", "is_visible"]
    list_editable = ["is_visible"]
    readonly_fields = ["booking", "worker", "customer", "rating", "comment"]

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        refresh_worker_rating(obj.worker_id)
