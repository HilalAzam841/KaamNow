from django.contrib import admin

from .models import SavedAddress


@admin.register(SavedAddress)
class SavedAddressAdmin(admin.ModelAdmin):
    list_display = ["id", "user", "label", "name", "area", "is_default"]
    list_filter = ["label"]
    raw_id_fields = ["user"]
