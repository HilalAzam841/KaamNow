from django.contrib import admin

from .models import ServicePackage


@admin.register(ServicePackage)
class ServicePackageAdmin(admin.ModelAdmin):
    list_display = ["title", "worker", "category", "price", "duration_minutes", "is_active", "is_hidden",
                    "times_booked"]
    list_filter = ["is_active", "is_hidden", "category"]
    search_fields = ["title", "worker__user__full_name"]
    raw_id_fields = ["worker", "hidden_by"]
