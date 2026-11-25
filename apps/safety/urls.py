from django.urls import path

from .views import EmergencyContactDetailView, EmergencyContactsView, SharedJobView

urlpatterns = [
    path("contacts/", EmergencyContactsView.as_view(), name="emergency-contacts"),
    path("contacts/<int:pk>/", EmergencyContactDetailView.as_view(), name="emergency-contact-detail"),
    path("shared/<str:token>/", SharedJobView.as_view(), name="shared-job"),
]
