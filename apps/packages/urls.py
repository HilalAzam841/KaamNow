from django.urls import path

from .views import BookPackageView, PackageDetailView, PackageListView

urlpatterns = [
    path("", PackageListView.as_view(), name="package-list"),
    path("<int:pk>/", PackageDetailView.as_view(), name="package-detail"),
    path("<int:pk>/book/", BookPackageView.as_view(), name="package-book"),
]
