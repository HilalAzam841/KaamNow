from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView

from apps.accounts.urls import auth_urlpatterns, worker_urlpatterns
from apps.billing.urls import featured_urlpatterns, payment_urlpatterns, subscription_urlpatterns
from apps.chat.views import BookingMessagesReadView, BookingMessagesView
from apps.common.views import health
from apps.tracking.views import BookingLocationView
from apps.jobs.urls import bookings_router, requests_router
from apps.offers.urls import offer_urlpatterns, request_offer_urlpatterns
from apps.reviews.views import ReviewCreateView, WorkerReviewsView

api_v1 = [
    path("health/", health, name="health"),
    path("auth/", include(auth_urlpatterns)),
    path("workers/<int:pk>/reviews/", WorkerReviewsView.as_view(), name="worker-reviews"),
    path("workers/", include(worker_urlpatterns)),
    path("services/", include("apps.catalog.urls")),
    path("requests/", include(request_offer_urlpatterns)),
    path("requests/", include(requests_router.urls)),
    path("offers/", include(offer_urlpatterns)),
    path("bookings/<int:booking_id>/messages/", BookingMessagesView.as_view(), name="booking-messages"),
    path("bookings/<int:booking_id>/messages/read/", BookingMessagesReadView.as_view(), name="booking-messages-read"),
    path("bookings/<int:booking_id>/location/", BookingLocationView.as_view(), name="booking-location"),
    path("bookings/", include(bookings_router.urls)),
    path("payments/", include(payment_urlpatterns)),
    path("subscriptions/", include(subscription_urlpatterns)),
    path("featured/", include(featured_urlpatterns)),
    path("reviews/", ReviewCreateView.as_view(), name="review-create"),
    path("notifications/", include("apps.notifications.urls")),
    path("complaints/", include("apps.support.urls")),
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
