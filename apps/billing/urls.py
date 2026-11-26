from django.urls import path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("", views.PaymentViewSet, basename="payment")

payment_urlpatterns = [
    path("earnings/", views.WorkerEarningsView.as_view(), name="worker-earnings"),
    path("earnings/report/", views.EarningsReportView.as_view(), name="earnings-report"),
    path("earnings/statement/", views.EarningsStatementView.as_view(), name="earnings-statement"),
    path("wallet/", views.WalletView.as_view(), name="worker-wallet"),
    path("payouts/", views.PayoutRequestView.as_view(), name="worker-payout"),
    path("payouts/<int:pk>/cancel/", views.PayoutCancelView.as_view(), name="worker-payout-cancel"),
    path("commission/pay/", views.CommissionPaymentView.as_view(), name="worker-commission-pay"),
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
