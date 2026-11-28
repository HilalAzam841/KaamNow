from django.contrib import admin

from .models import JobPhoto


@admin.register(JobPhoto)
class JobPhotoAdmin(admin.ModelAdmin):
    """Read-only list. The pictures are private: open them from the admin app, which audits each view."""

    list_display = ["booking", "kind", "uploaded_by", "created_at"]
    list_filter = ["kind"]
    search_fields = ["booking__id"]
    readonly_fields = ["booking", "kind", "caption", "uploaded_by", "created_at"]
    exclude = ["image"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
