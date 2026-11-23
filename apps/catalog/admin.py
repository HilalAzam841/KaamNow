from django.contrib import admin

from .models import ServiceCategory, WorkerService


@admin.register(ServiceCategory)
class ServiceCategoryAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "is_active", "sort_order"]
    list_editable = ["is_active", "sort_order"]
    search_fields = ["name"]
    prepopulated_fields = {"slug": ("name",)}


@admin.register(WorkerService)
class WorkerServiceAdmin(admin.ModelAdmin):
    list_display = ["worker", "category", "starting_price", "is_active"]
    list_filter = ["category", "is_active"]
    raw_id_fields = ["worker"]
