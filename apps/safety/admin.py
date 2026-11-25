from django.contrib import admin

from .models import EmergencyContact, SosAlert, TripShare


@admin.register(SosAlert)
class SosAlertAdmin(admin.ModelAdmin):
    list_display = ["id", "booking", "raised_by", "role", "status", "created_at"]
    list_filter = ["status", "role"]
    raw_id_fields = ["booking", "raised_by", "handled_by"]


@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ["name", "user", "created_at"]
    raw_id_fields = ["user"]


@admin.register(TripShare)
class TripShareAdmin(admin.ModelAdmin):
    list_display = ["booking", "created_by", "expires_at", "revoked_at"]
    raw_id_fields = ["booking", "created_by"]
    exclude = ["token_hash"]
