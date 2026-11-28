from django.contrib import admin

from .models import GuaranteeClaim


@admin.register(GuaranteeClaim)
class GuaranteeClaimAdmin(admin.ModelAdmin):
    list_display = ["id", "booking", "customer", "worker", "status", "created_at"]
    list_filter = ["status"]
    search_fields = ["booking__id", "customer__phone"]
    readonly_fields = ["booking", "customer", "worker", "problem", "status", "redo_time", "worker_note", "respond_by",
                       "accepted_at", "redo_done_at", "closed_at", "complaint", "created_at", "updated_at"]

    def has_add_permission(self, request):
        return False
