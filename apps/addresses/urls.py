from django.urls import path

from .views import AddressDetailView, AddressesView, MakeDefaultView

urlpatterns = [
    path("", AddressesView.as_view(), name="addresses"),
    path("<int:pk>/", AddressDetailView.as_view(), name="address-detail"),
    path("<int:pk>/make-default/", MakeDefaultView.as_view(), name="address-make-default"),
]
