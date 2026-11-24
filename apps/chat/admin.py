from django.contrib import admin

from .models import ChatMessage


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    """Read-only, for dispute investigation by staff. Messages cannot be edited or deleted."""

    list_display = ["booking", "sender", "created_at", "is_read"]
    list_filter = ["is_read"]
    search_fields = ["booking__id"]
    readonly_fields = ["booking", "sender", "body", "is_read", "read_at", "created_at"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
