from django.contrib import admin

from .models import RecurringJob, RecurringVisit


@admin.register(RecurringJob)
class RecurringJobAdmin(admin.ModelAdmin):
    list_display = ["title", "customer", "worker", "frequency", "next_visit", "status"]
    list_filter = ["frequency", "status"]
    raw_id_fields = ["customer", "worker", "source_booking"]


@admin.register(RecurringVisit)
class RecurringVisitAdmin(admin.ModelAdmin):
    list_display = ["plan", "scheduled_for", "outcome", "request"]
    raw_id_fields = ["plan", "request"]
