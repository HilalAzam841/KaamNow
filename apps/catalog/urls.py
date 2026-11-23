from rest_framework.routers import DefaultRouter

from .views import ServiceCategoryViewSet, WorkerServiceViewSet

router = DefaultRouter()
router.register("categories", ServiceCategoryViewSet, basename="category")
router.register("workers", WorkerServiceViewSet, basename="worker-service")

urlpatterns = router.urls
