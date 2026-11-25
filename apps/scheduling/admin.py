from django.contrib import admin

from .models import TimeOff, WorkingHours


@admin.register(WorkingHours)
class WorkingHoursAdmin(admin.ModelAdmin):
    list_display = ["worker", "weekday", "start_time", "end_time"]


@admin.register(TimeOff)
class TimeOffAdmin(admin.ModelAdmin):
    list_display = ["worker", "start_date", "end_date", "reason"]
