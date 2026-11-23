from django.contrib import admin

from .models import Booking, BookingStatusLog, ServiceRequest, ServiceRequestImage


class ServiceRequestImageInline(admin.TabularInline):
    model = ServiceRequestImage
    extra = 0


@admin.register(ServiceRequest)
class ServiceRequestAdmin(admin.ModelAdmin):
    list_display = ["id", "title", "category", "customer", "status", "preferred_time", "created_at"]
    list_filter = ["status", "category"]
    search_fields = ["title", "customer__phone", "customer__full_name"]
    raw_id_fields = ["customer"]
    inlines = [ServiceRequestImageInline]


class BookingStatusLogInline(admin.TabularInline):
    model = BookingStatusLog
    extra = 0
    readonly_fields = ["from_status", "to_status", "changed_by", "note", "created_at"]
    can_delete = False


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ["id", "request", "customer", "worker", "agreed_price", "status", "created_at"]
    list_filter = ["status"]
    search_fields = ["id", "customer__phone", "worker__user__phone"]
    raw_id_fields = ["request", "offer", "customer", "worker", "cancelled_by"]
    # OTP internals and the locked price are never editable from admin.
    exclude = ["completion_otp_hash"]
    readonly_fields = ["agreed_price", "completion_otp_expires_at", "completion_otp_attempts",
                       "completion_otp_sent_at", "completed_via"]
    inlines = [BookingStatusLogInline]
