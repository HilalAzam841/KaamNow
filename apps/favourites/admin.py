from django.contrib import admin

from .models import FavouriteWorker


@admin.register(FavouriteWorker)
class FavouriteWorkerAdmin(admin.ModelAdmin):
    list_display = ["customer", "worker", "created_at"]
    raw_id_fields = ["customer", "worker"]
