from django.contrib import admin

from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from .models import (
    Commission,
    FeaturedListing,
    FeaturedPlan,
    LedgerEntry,
    Payment,
    PlatformSettings,
    SubscriptionPlan,
    WorkerSubscription,
)


@admin.register(PlatformSettings)
class PlatformSettingsAdmin(admin.ModelAdmin):
    list_display = ["commission_percent", "emergency_fee", "emergency_enabled", "updated_by", "updated_at"]
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


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = ["name", "price", "duration_days", "commission_percent", "daily_offer_limit", "is_default",
                    "is_active", "sort_order"]
    list_editable = ["is_active", "sort_order"]
    prepopulated_fields = {"slug": ("name",)}


@admin.register(WorkerSubscription)
class WorkerSubscriptionAdmin(admin.ModelAdmin):
    list_display = ["worker", "plan", "status", "starts_at", "ends_at", "amount"]
    list_filter = ["status", "plan"]
    raw_id_fields = ["worker", "payment", "activated_by"]
    readonly_fields = ["amount", "payment", "activated_by"]


@admin.register(FeaturedPlan)
class FeaturedPlanAdmin(admin.ModelAdmin):
    list_display = ["name", "duration_days", "price", "is_active"]
    list_editable = ["is_active"]


@admin.register(FeaturedListing)
class FeaturedListingAdmin(admin.ModelAdmin):
    list_display = ["worker", "category", "plan", "status", "starts_at", "ends_at"]
    list_filter = ["status", "category"]
    raw_id_fields = ["worker", "payment"]
    readonly_fields = ["amount", "payment"]
