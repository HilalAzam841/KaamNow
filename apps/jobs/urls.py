from rest_framework.routers import DefaultRouter

from .views import BookingViewSet, ServiceRequestViewSet

requests_router = DefaultRouter()
requests_router.register("", ServiceRequestViewSet, basename="service-request")

bookings_router = DefaultRouter()
bookings_router.register("", BookingViewSet, basename="booking")
