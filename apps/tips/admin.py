from django.contrib import admin

from .models import Tip


@admin.register(Tip)
class TipAdmin(admin.ModelAdmin):
    list_display = ["booking", "customer", "worker", "amount", "method", "status", "created_at"]
    list_filter = ["status", "method"]
    raw_id_fields = ["booking", "customer", "worker", "payment"]
    readonly_fields = ["amount", "method", "payment", "paid_at"]
