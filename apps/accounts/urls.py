from django.urls import path

from . import views

auth_urlpatterns = [
    path("register/", views.RegisterView.as_view(), name="auth-register"),
    path("login/", views.LoginView.as_view(), name="auth-login"),
    path("token/refresh/", views.RefreshView.as_view(), name="auth-token-refresh"),
    path("logout/", views.LogoutView.as_view(), name="auth-logout"),
    path("me/", views.MeView.as_view(), name="auth-me"),
    path("password-reset/", views.PasswordResetRequestView.as_view(), name="auth-password-reset"),
    path("password-reset/confirm/", views.PasswordResetConfirmView.as_view(), name="auth-password-reset-confirm"),
    path("password-change/", views.PasswordChangeView.as_view(), name="auth-password-change"),
]

worker_urlpatterns = [
    path("me/", views.WorkerMeView.as_view(), name="worker-me"),
    path("documents/", views.WorkerDocumentView.as_view(), name="worker-documents"),
    path("nearby/", views.NearbyWorkersView.as_view(), name="worker-nearby"),
    path("availability/", views.WorkerAvailabilityView.as_view(), name="worker-availability"),
    path("<int:pk>/", views.PublicWorkerDetailView.as_view(), name="worker-detail"),
]
