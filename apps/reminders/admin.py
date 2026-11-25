from django.contrib import admin

from .models import BookingReminder, NoShowReport


@admin.register(BookingReminder)
class BookingReminderAdmin(admin.ModelAdmin):
    list_display = ["booking", "kind", "sent_at", "sms_sent"]
    raw_id_fields = ["booking"]


@admin.register(NoShowReport)
class NoShowReportAdmin(admin.ModelAdmin):
    list_display = ["booking", "side", "against", "review", "created_at"]
    list_filter = ["side", "review"]
    raw_id_fields = ["booking", "reported_by", "against", "reviewed_by"]
