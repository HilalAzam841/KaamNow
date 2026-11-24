from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils import timezone

from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from . import services
from .models import User, WorkerDocument, WorkerProfile


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ["-date_joined"]
    list_display = ["phone", "full_name", "email", "role", "phone_verified_at", "is_active", "is_suspended", "date_joined"]
    list_filter = ["role", "is_active", "is_suspended", "is_staff"]
    search_fields = ["phone", "full_name", "email"]
    readonly_fields = ["date_joined", "last_login", "created_at", "updated_at"]
    fieldsets = (
        (None, {"fields": ("phone", "password")}),
        ("Profile", {"fields": ("full_name", "email", "role", "avatar", "default_address")}),
        ("Status", {"fields": ("is_active", "is_suspended", "suspended_reason")}),
        ("Permissions", {"fields": ("is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Dates", {"fields": ("date_joined", "last_login", "created_at", "updated_at")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("phone", "full_name", "role", "password1", "password2")}),)


class WorkerDocumentInline(admin.TabularInline):
    model = WorkerDocument
    extra = 0
    fields = ["document_type", "original_filename", "status", "created_at"]
    readonly_fields = ["document_type", "original_filename", "created_at"]
    can_delete = False


@admin.register(WorkerProfile)
class WorkerProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "verification_status", "is_available", "service_area", "average_rating",
                    "completed_jobs_count", "created_at"]
    list_filter = ["verification_status", "is_available"]
    search_fields = ["user__full_name", "user__phone", "cnic_number"]
    raw_id_fields = ["user", "verified_by"]
    readonly_fields = ["average_rating", "rating_count", "completed_jobs_count", "verified_at", "verified_by"]
    inlines = [WorkerDocumentInline]
    actions = ["verify_selected"]

    @admin.action(description="Verify selected workers (requires CNIC documents)")
    def verify_selected(self, request, queryset):
        done = 0
        for worker in queryset:
            try:
                services.verify_worker(worker, request.user, request)
                done += 1
            except Exception as exc:  # noqa: BLE001 - show reason per worker
                self.message_user(request, f"{worker}: {exc}", level="warning")
        self.message_user(request, f"Verified {done} worker(s).")


@admin.register(WorkerDocument)
class WorkerDocumentAdmin(admin.ModelAdmin):
    list_display = ["worker", "document_type", "status", "created_at"]
    list_filter = ["document_type", "status"]
    readonly_fields = ["worker", "document_type", "original_filename", "created_at"]
    exclude = ["file"]  # Private file: download via the audited admin API endpoint.

    def save_model(self, request, obj, form, change):
        if change and "status" in form.changed_data:
            obj.reviewed_at = timezone.now()
            audit(request.user, AuditLog.Action.WORKER_VERIFIED if obj.status == "approved"
                  else AuditLog.Action.WORKER_REJECTED, obj, request, document_status=obj.status)
        super().save_model(request, obj, form, change)
