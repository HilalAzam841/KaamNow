from django.urls import path

from . import views

request_offer_urlpatterns = [
    path("<int:request_id>/offers/", views.RequestOffersView.as_view(), name="request-offers"),
]

offer_urlpatterns = [
    path("", views.MyOffersView.as_view(), name="my-offers"),
    path("<int:pk>/", views.OfferDetailView.as_view(), name="offer-detail"),
    path("<int:pk>/accept/", views.OfferAcceptView.as_view(), name="offer-accept"),
    path("<int:pk>/reject/", views.OfferRejectView.as_view(), name="offer-reject"),
    path("<int:pk>/negotiate/", views.OfferNegotiateView.as_view(), name="offer-negotiate"),
    path("<int:pk>/negotiations/", views.OfferNegotiationHistoryView.as_view(), name="offer-negotiations"),
]
