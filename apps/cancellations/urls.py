from rest_framework.routers import DefaultRouter

from .views import CancellationFeeViewSet

router = DefaultRouter()
router.register("", CancellationFeeViewSet, basename="cancellation-fee")
urlpatterns = router.urls
