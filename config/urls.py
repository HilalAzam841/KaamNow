from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView

from apps.accounts.urls import auth_urlpatterns, worker_urlpatterns
from apps.billing.urls import featured_urlpatterns, payment_urlpatterns, subscription_urlpatterns
from apps.chat.views import BookingMessagesReadView, BookingMessagesView
from apps.common.views import app_config, health
from apps.tracking.views import BookingLocationView
from apps.safety.views import BookingShareView, BookingSosView
from apps.portfolio.views import MyPortfolioPhotoView, MyPortfolioReorderView, MyPortfolioView, WorkerPortfolioView
from apps.jobs.urls import bookings_router, requests_router
from apps.offers.urls import offer_urlpatterns, request_offer_urlpatterns
from apps.promotions.urls import referral_urlpatterns
from apps.scheduling.views import MyScheduleView, MyTimeOffDetailView, MyTimeOffView, SlotsView, WorkerSlotsView
from apps.reviews.views import ReviewCreateView, WorkerReviewsView

api_v1 = [
    path("health/", health, name="health"),
    path("app/config/", app_config, name="app-config"),
    path("auth/", include(auth_urlpatterns)),
    path("workers/<int:pk>/reviews/", WorkerReviewsView.as_view(), name="worker-reviews"),
    path("workers/<int:pk>/slots/", WorkerSlotsView.as_view(), name="worker-slots"),
    path("workers/me/schedule/", MyScheduleView.as_view(), name="worker-schedule"),
    path("workers/me/portfolio/", MyPortfolioView.as_view(), name="worker-portfolio"),
    path("workers/me/portfolio/reorder/", MyPortfolioReorderView.as_view(), name="worker-portfolio-reorder"),
    path("workers/me/portfolio/<int:pk>/", MyPortfolioPhotoView.as_view(), name="worker-portfolio-photo"),
    path("workers/<int:pk>/portfolio/", WorkerPortfolioView.as_view(), name="worker-public-portfolio"),
    path("workers/me/time-off/", MyTimeOffView.as_view(), name="worker-time-off"),
    path("workers/me/time-off/<int:pk>/", MyTimeOffDetailView.as_view(), name="worker-time-off-detail"),
    path("workers/", include(worker_urlpatterns)),
    path("services/", include("apps.catalog.urls")),
    path("requests/slots/", SlotsView.as_view(), name="request-slots"),
    path("requests/", include(request_offer_urlpatterns)),
    path("requests/", include(requests_router.urls)),
    path("offers/", include(offer_urlpatterns)),
    path("bookings/<int:booking_id>/messages/", BookingMessagesView.as_view(), name="booking-messages"),
    path("bookings/<int:booking_id>/messages/read/", BookingMessagesReadView.as_view(), name="booking-messages-read"),
    path("bookings/<int:booking_id>/location/", BookingLocationView.as_view(), name="booking-location"),
    path("bookings/<int:booking_id>/sos/", BookingSosView.as_view(), name="booking-sos"),
    path("bookings/<int:booking_id>/share/", BookingShareView.as_view(), name="booking-share"),
    path("bookings/", include(bookings_router.urls)),
    path("payments/", include(payment_urlpatterns)),
    path("subscriptions/", include(subscription_urlpatterns)),
    path("featured/", include(featured_urlpatterns)),
    path("reviews/", ReviewCreateView.as_view(), name="review-create"),
    path("notifications/", include("apps.notifications.urls")),
    path("complaints/", include("apps.support.urls")),
    path("promos/", include("apps.promotions.urls")),
    path("favourites/", include("apps.favourites.urls")),
    path("recurring-jobs/", include("apps.recurring.urls")),
    path("safety/", include("apps.safety.urls")),
    path("addresses/", include("apps.addresses.urls")),
    path("referrals/", include(referral_urlpatterns)),
    path("admin/", include("apps.dashboard.urls")),
]

urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("api/v1/", include(api_v1)),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("api/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

admin.site.site_header = "KaamNow Administration"
admin.site.site_title = "KaamNow Admin"
