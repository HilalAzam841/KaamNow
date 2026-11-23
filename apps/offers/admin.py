from django.contrib import admin

from .models import Negotiation, WorkerOffer


class NegotiationInline(admin.TabularInline):
    model = Negotiation
    extra = 0
    readonly_fields = ["party", "author", "action", "amount", "message", "created_at"]
    can_delete = False


@admin.register(WorkerOffer)
class WorkerOfferAdmin(admin.ModelAdmin):
    list_display = ["id", "request", "worker", "initial_price", "current_price", "awaiting", "status", "created_at"]
    list_filter = ["status", "awaiting"]
    raw_id_fields = ["request", "worker"]
    readonly_fields = ["initial_price", "current_price"]
    inlines = [NegotiationInline]
