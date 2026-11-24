from django.contrib import admin

from .models import Complaint


@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = ["id", "subject", "category", "raised_by", "against_user", "status", "created_at"]
    list_filter = ["status", "category"]
    search_fields = ["subject", "raised_by__phone", "against_user__phone"]
    raw_id_fields = ["raised_by", "against_user", "booking", "resolved_by"]
    readonly_fields = ["raised_by", "against_user", "booking", "category", "subject", "description", "resolved_by",
                       "resolved_at"]
