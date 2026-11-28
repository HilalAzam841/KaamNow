from django.urls import path
from rest_framework.routers import SimpleRouter

from .views import ReviewCreateView, ReviewViewSet

router = SimpleRouter()
router.register("", ReviewViewSet, basename="review")
urlpatterns = [path("", ReviewCreateView.as_view(), name="review-create")] + router.urls
