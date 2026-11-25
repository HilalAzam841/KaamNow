from rest_framework.routers import DefaultRouter

from .views import RecurringJobViewSet

router = DefaultRouter()
router.register("", RecurringJobViewSet, basename="recurring-job")
urlpatterns = router.urls
