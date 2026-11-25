from django.contrib import admin

from .models import PortfolioPhoto


@admin.register(PortfolioPhoto)
class PortfolioPhotoAdmin(admin.ModelAdmin):
    list_display = ["id", "worker", "caption", "is_hidden", "created_at"]
    list_filter = ["is_hidden"]
    raw_id_fields = ["worker", "category", "booking", "hidden_by"]
