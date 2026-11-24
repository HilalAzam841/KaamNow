from django.urls import path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("", views.PaymentViewSet, basename="payment")

payment_urlpatterns = [
    path("earnings/", views.WorkerEarningsView.as_view(), name="worker-earnings"),
    path("callbacks/jazzcash/", views.JazzCashCallbackView.as_view(), name="callback-jazzcash"),
    path("callbacks/easypaisa/", views.EasypaisaCallbackView.as_view(), name="callback-easypaisa"),
] + router.urls

subscription_urlpatterns = [
    path("", views.SubscribeView.as_view(), name="subscribe"),
    path("plans/", views.SubscriptionPlanListView.as_view(), name="subscription-plans"),
    path("my-subscription/", views.MySubscriptionView.as_view(), name="my-subscription"),
    path("history/", views.SubscriptionHistoryView.as_view(), name="subscription-history"),
]

featured_urlpatterns = [
    path("", views.FeaturedPurchaseView.as_view(), name="featured"),
    path("plans/", views.FeaturedPlanListView.as_view(), name="featured-plans"),
]

urlpatterns = payment_urlpatterns
