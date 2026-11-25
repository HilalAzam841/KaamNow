from django.urls import path

from .views import FavouriteDetailView, FavouritesView, RecentWorkersView

urlpatterns = [
    path("", FavouritesView.as_view(), name="favourites"),
    path("recent/", RecentWorkersView.as_view(), name="favourites-recent"),
    path("<int:worker_id>/", FavouriteDetailView.as_view(), name="favourite-detail"),
]
