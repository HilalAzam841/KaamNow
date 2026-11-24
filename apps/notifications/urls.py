from rest_framework.routers import DefaultRouter

from django.urls import path

from .views import DeviceTokenView, NotificationViewSet

router = DefaultRouter()
router.register("", NotificationViewSet, basename="notification")
urlpatterns = [path("devices/", DeviceTokenView.as_view(), name="device-tokens")] + router.urls
