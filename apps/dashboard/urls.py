from django.urls import path
from rest_framework.routers import DefaultRouter

from apps.promotions.views import AdminPromoCodeViewSet
from apps.reminders.views import AdminNoShowViewSet
from apps.safety.views import AdminSosAlertViewSet
from apps.portfolio.views import AdminPortfolioPhotoViewSet
from apps.packages.views import AdminPackageViewSet
from apps.cancellations.views import AdminCancellationFeeViewSet
from apps.reviews.views import AdminReviewViewSet
from apps.tips.views import AdminTipViewSet
from apps.jobphotos.views import AdminBookingPhotoFileView, AdminBookingPhotosView
from apps.guarantee.views import AdminGuaranteeClaimViewSet

from . import views

router = DefaultRouter()
router.register("subscription-plans", views.AdminSubscriptionPlanViewSet, basename="admin-subscription-plan")
router.register("featured-plans", views.AdminFeaturedPlanViewSet, basename="admin-featured-plan")
router.register("subscriptions", views.AdminSubscriptionViewSet, basename="admin-subscription")
router.register("featured-listings", views.AdminFeaturedListingViewSet, basename="admin-featured-listing")
router.register("complaints", views.AdminComplaintViewSet, basename="admin-complaint")
router.register("promo-codes", AdminPromoCodeViewSet, basename="admin-promo-code")
router.register("payments", views.AdminPaymentViewSet, basename="admin-payment")
router.register("no-shows", AdminNoShowViewSet, basename="admin-no-show")
router.register("sos-alerts", AdminSosAlertViewSet, basename="admin-sos-alert")
router.register("portfolio-photos", AdminPortfolioPhotoViewSet, basename="admin-portfolio-photo")
router.register("packages", AdminPackageViewSet, basename="admin-package")
router.register("cancellation-fees", AdminCancellationFeeViewSet, basename="admin-cancellation-fee")
router.register("tips", AdminTipViewSet, basename="admin-tip")
router.register("guarantee-claims", AdminGuaranteeClaimViewSet, basename="admin-guarantee-claim")
router.register("reviews", AdminReviewViewSet, basename="admin-review")
router.register("settlements", views.AdminSettlementViewSet, basename="admin-settlement")

urlpatterns = [
    path("dashboard/", views.DashboardView.as_view(), name="admin-dashboard"),
    path("workers/pending/", views.PendingWorkersView.as_view(), name="admin-workers-pending"),
    path("workers/<int:pk>/", views.AdminWorkerDetailView.as_view(), name="admin-worker-detail"),
    path("workers/<int:pk>/verify/", views.VerifyWorkerView.as_view(), name="admin-worker-verify"),
    path("workers/<int:pk>/reject/", views.RejectWorkerView.as_view(), name="admin-worker-reject"),
    path("workers/<int:pk>/record-commission/", views.RecordCommissionView.as_view(),
         name="admin-worker-record-commission"),
    path("worker-balances/", views.WorkerBalancesView.as_view(), name="admin-worker-balances"),
    path("documents/<int:pk>/file/", views.WorkerDocumentFileView.as_view(), name="admin-document-file"),
    path("users/", views.AdminUsersView.as_view(), name="admin-users"),
    path("users/<int:pk>/suspend/", views.SuspendUserView.as_view(), name="admin-user-suspend"),
    path("users/<int:pk>/reactivate/", views.ReactivateUserView.as_view(), name="admin-user-reactivate"),
    path("requests/", views.AdminRequestsView.as_view(), name="admin-requests"),
    path("bookings/", views.AdminBookingsView.as_view(), name="admin-bookings"),
    path("bookings/<int:booking_id>/photos/", AdminBookingPhotosView.as_view(), name="admin-booking-photos"),
    path("bookings/<int:booking_id>/photos/<int:pk>/file/", AdminBookingPhotoFileView.as_view(),
         name="admin-booking-photo-file"),
    path("revenue/", views.RevenueView.as_view(), name="admin-revenue"),
    path("commissions/", views.CommissionsView.as_view(), name="admin-commissions"),
    path("settings/", views.CommissionSettingsView.as_view(), name="admin-settings"),
    path("settings/commission/", views.CommissionSettingsView.as_view(), name="admin-commission-settings"),
    path("revenue/other/", views.OtherRevenueView.as_view(), name="admin-revenue-other"),
    path("reports/", views.ReportsView.as_view(), name="admin-reports"),
    path("audit-logs/", views.AuditLogView.as_view(), name="admin-audit-logs"),
]
urlpatterns += router.urls
