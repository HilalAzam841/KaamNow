from django.contrib import admin

from .models import BookingLocation


@admin.register(BookingLocation)
class BookingLocationAdmin(admin.ModelAdmin):
    list_display = ["booking", "worker", "latitude", "longitude", "speed_kmh", "recorded_at"]
    readonly_fields = ["booking", "worker", "latitude", "longitude", "accuracy_m", "heading", "speed_kmh",
                       "recorded_at"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
