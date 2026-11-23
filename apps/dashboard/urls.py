from django.urls import path

from . import views

urlpatterns = [
    path("dashboard/", views.DashboardView.as_view(), name="admin-dashboard"),
    path("workers/pending/", views.PendingWorkersView.as_view(), name="admin-workers-pending"),
    path("workers/<int:pk>/", views.AdminWorkerDetailView.as_view(), name="admin-worker-detail"),
    path("workers/<int:pk>/verify/", views.VerifyWorkerView.as_view(), name="admin-worker-verify"),
    path("workers/<int:pk>/reject/", views.RejectWorkerView.as_view(), name="admin-worker-reject"),
    path("documents/<int:pk>/file/", views.WorkerDocumentFileView.as_view(), name="admin-document-file"),
    path("users/", views.AdminUsersView.as_view(), name="admin-users"),
    path("users/<int:pk>/suspend/", views.SuspendUserView.as_view(), name="admin-user-suspend"),
    path("users/<int:pk>/reactivate/", views.ReactivateUserView.as_view(), name="admin-user-reactivate"),
    path("requests/", views.AdminRequestsView.as_view(), name="admin-requests"),
    path("bookings/", views.AdminBookingsView.as_view(), name="admin-bookings"),
    path("revenue/", views.RevenueView.as_view(), name="admin-revenue"),
    path("commissions/", views.CommissionsView.as_view(), name="admin-commissions"),
    path("settings/commission/", views.CommissionSettingsView.as_view(), name="admin-commission-settings"),
    path("reports/", views.ReportsView.as_view(), name="admin-reports"),
    path("audit-logs/", views.AuditLogView.as_view(), name="admin-audit-logs"),
]
