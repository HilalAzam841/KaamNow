from rest_framework.routers import DefaultRouter

from django.urls import path

from .views import DeviceTokenView, NotificationViewSet, WebPushSubscribeView, WebPushUnsubscribeView

router = DefaultRouter()
router.register("", NotificationViewSet, basename="notification")
urlpatterns = [
    path("devices/", DeviceTokenView.as_view(), name="device-tokens"),
    path("web-push/subscribe/", WebPushSubscribeView.as_view(), name="web-push-subscribe"),
    path("web-push/unsubscribe/", WebPushUnsubscribeView.as_view(), name="web-push-unsubscribe"),
] + router.urls
