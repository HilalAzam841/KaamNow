from rest_framework.routers import DefaultRouter

from .views import GuaranteeClaimViewSet

router = DefaultRouter()
router.register("", GuaranteeClaimViewSet, basename="guarantee-claim")
urlpatterns = router.urls
