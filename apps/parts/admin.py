from django.contrib import admin

from .models import JobPart


@admin.register(JobPart)
class JobPartAdmin(admin.ModelAdmin):
    """Read-only. Receipt photos are private: open them from the admin app, which audits each view."""

    list_display = ["booking", "name", "quantity", "unit_price", "status", "created_at"]
    list_filter = ["status"]
    search_fields = ["booking__id", "name"]
    readonly_fields = ["booking", "name", "quantity", "unit_price", "status", "reject_reason", "added_by",
                       "decided_at", "created_at"]
    exclude = ["receipt"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
