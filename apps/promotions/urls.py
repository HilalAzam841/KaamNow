from django.urls import path

from . import views

urlpatterns = [
    path("check/", views.PromoCheckView.as_view(), name="promo-check"),
]
referral_urlpatterns = [
    path("me/", views.ReferralSummaryView.as_view(), name="referral-me"),
]
