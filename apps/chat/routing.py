from django.urls import path

from .consumers import BookingConsumer

websocket_urlpatterns = [
    path("ws/bookings/<int:booking_id>/", BookingConsumer.as_asgi()),
]
