from django.contrib import admin

from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from .models import Commission, LedgerEntry, Payment, PlatformSettings


@admin.register(PlatformSettings)
class PlatformSettingsAdmin(admin.ModelAdmin):
    list_display = ["commission_percent", "updated_by", "updated_at"]
    readonly_fields = ["updated_by"]

    def has_add_permission(self, request):
        return not PlatformSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False

    def save_model(self, request, obj, form, change):
        obj.updated_by = request.user
        super().save_model(request, obj, form, change)
        audit(request.user, AuditLog.Action.COMMISSION_CHANGED, obj, request, new=str(obj.commission_percent))


@admin.register(Commission)
class CommissionAdmin(admin.ModelAdmin):
    list_display = ["booking", "worker", "gross_amount", "rate_percent", "commission_amount", "worker_earning",
                    "status", "created_at"]
    list_filter = ["status"]
    readonly_fields = ["booking", "worker", "gross_amount", "rate_percent", "commission_amount", "worker_earning"]


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ["reference", "booking", "payer", "amount", "method", "status", "created_at"]
    list_filter = ["method", "status"]
    search_fields = ["reference", "gateway_transaction_id"]
    readonly_fields = ["booking", "payer", "amount", "method", "reference", "gateway_transaction_id",
                       "confirmed_at", "confirmed_by"]


@admin.register(LedgerEntry)
class LedgerEntryAdmin(admin.ModelAdmin):
    list_display = ["payment", "booking", "entry_type", "amount", "created_at"]
    list_filter = ["entry_type"]

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
