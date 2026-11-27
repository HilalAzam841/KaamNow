from django.contrib import admin

from .models import CancellationFee


@admin.register(CancellationFee)
class CancellationFeeAdmin(admin.ModelAdmin):
    list_display = ["booking", "customer", "worker", "reason", "amount", "worker_share", "status", "created_at"]
    list_filter = ["status", "reason"]
    raw_id_fields = ["booking", "customer", "worker", "payment", "waived_by"]
    readonly_fields = ["amount", "worker_share", "commission_percent", "payment", "paid_at"]
