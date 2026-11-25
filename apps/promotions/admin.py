from django.contrib import admin

from .models import CreditEntry, PromoCode, PromoRedemption, Referral


@admin.register(PromoCode)
class PromoCodeAdmin(admin.ModelAdmin):
    list_display = ["code", "kind", "value", "is_active", "starts_at", "ends_at", "max_uses"]
    search_fields = ["code", "description"]


@admin.register(PromoRedemption)
class PromoRedemptionAdmin(admin.ModelAdmin):
    list_display = ["promo", "user", "payment", "amount", "status", "created_at"]
    list_filter = ["status"]


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ["referrer", "referee", "status", "referrer_reward", "rewarded_at"]
    list_filter = ["status"]


@admin.register(CreditEntry)
class CreditEntryAdmin(admin.ModelAdmin):
    list_display = ["user", "amount", "kind", "payment", "created_at"]
    list_filter = ["kind"]
