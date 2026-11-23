from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import PaymentViewSet, WorkerEarningsView

router = DefaultRouter()
router.register("", PaymentViewSet, basename="payment")

urlpatterns = [path("earnings/", WorkerEarningsView.as_view(), name="worker-earnings")] + router.urls
