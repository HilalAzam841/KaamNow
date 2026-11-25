"""
Django settings for the KaamNow backend.

All secrets and environment-specific values are read from environment
variables (optionally loaded from a local `.env` file). See `.env.example`.
"""

import os
from datetime import timedelta
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / ".env")


def env(name, default=None, required=False):
    value = os.environ.get(name, default)
    if required and value in (None, ""):
        raise ImproperlyConfigured(f"Environment variable {name} is required.")
    return value


def env_bool(name, default=False):
    return str(env(name, str(default))).strip().lower() in {"1", "true", "yes", "on"}


def env_list(name, default=""):
    return [item.strip() for item in str(env(name, default)).split(",") if item.strip()]


DEBUG = env_bool("DJANGO_DEBUG", False)
SECRET_KEY = env("DJANGO_SECRET_KEY", "insecure-dev-key-change-me" if DEBUG else None, required=not DEBUG)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")

INSTALLED_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "drf_spectacular",
    "corsheaders",
    "channels",
    # KaamNow apps
    "apps.common",
    "apps.accounts",
    "apps.catalog",
    "apps.jobs",
    "apps.offers",
    "apps.billing",
    "apps.reviews",
    "apps.notifications",
    "apps.dashboard",
    "apps.chat",
    "apps.tracking",
    "apps.support",
    "apps.promotions",
    "apps.favourites",
    "apps.reminders",
    "apps.recurring",
    "apps.safety",
    "apps.portfolio",
    "apps.scheduling",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    # Picks English or Urdu from the app's Accept-Language header (see LANGUAGES).
    "django.middleware.locale.LocaleMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# --- Database (PostgreSQL) -------------------------------------------------
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": env("POSTGRES_DB", "kaamnow"),
        "USER": env("POSTGRES_USER", "kaamnow"),
        "PASSWORD": env("POSTGRES_PASSWORD", ""),
        "HOST": env("POSTGRES_HOST", "localhost"),
        "PORT": env("POSTGRES_PORT", "5432"),
        "CONN_MAX_AGE": int(env("POSTGRES_CONN_MAX_AGE", "60")),
        "OPTIONS": {"sslmode": env("POSTGRES_SSLMODE", "prefer")},
    }
}

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 8}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
]

LANGUAGE_CODE = "en"
LANGUAGES = [("en", "English"), ("ur", "Urdu")]
LOCALE_PATHS = [BASE_DIR / "locale"]
TIME_ZONE = "Asia/Karachi"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}

# Public media (profile pictures, request images).
MEDIA_URL = "/media/"
MEDIA_ROOT = Path(env("MEDIA_ROOT", str(BASE_DIR / "media")))
# Private media (CNIC documents). Never served by a URL; only streamed to admins.
PRIVATE_MEDIA_ROOT = Path(env("PRIVATE_MEDIA_ROOT", str(BASE_DIR / "private_media")))

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- Upload limits ---------------------------------------------------------
MAX_IMAGE_UPLOAD_MB = int(env("MAX_IMAGE_UPLOAD_MB", "5"))
MAX_DOCUMENT_UPLOAD_MB = int(env("MAX_DOCUMENT_UPLOAD_MB", "5"))
MAX_REQUEST_IMAGES = int(env("MAX_REQUEST_IMAGES", "5"))
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024

# --- Django REST Framework -------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ("apps.accounts.authentication.KaamNowJWTAuthentication",),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_RENDERER_CLASSES": ("apps.common.renderers.EnvelopeJSONRenderer",),
    "DEFAULT_PARSER_CLASSES": (
        "rest_framework.parsers.JSONParser",
        "rest_framework.parsers.MultiPartParser",
        "rest_framework.parsers.FormParser",
    ),
    "DEFAULT_PAGINATION_CLASS": "apps.common.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.OrderingFilter",
        "rest_framework.filters.SearchFilter",
    ),
    "EXCEPTION_HANDLER": "apps.common.exceptions.api_exception_handler",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_THROTTLE_CLASSES": (
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
        "rest_framework.throttling.ScopedRateThrottle",
    ),
    "DEFAULT_THROTTLE_RATES": {
        "anon": env("THROTTLE_ANON", "60/min"),
        "user": env("THROTTLE_USER", "600/min"),
        "auth": env("THROTTLE_AUTH", "10/min"),
        "password_reset": env("THROTTLE_PASSWORD_RESET", "5/hour"),
        "phone_code": env("THROTTLE_PHONE_CODE", "10/hour"),
        "otp": env("THROTTLE_OTP", "10/min"),
        "offers": env("THROTTLE_OFFERS", "60/min"),
        "chat": env("THROTTLE_CHAT", "60/min"),
        "location": env("THROTTLE_LOCATION", "120/min"),
        "payment_callback": env("THROTTLE_PAYMENT_CALLBACK", "120/min"),
        "payout": env("THROTTLE_PAYOUT", "20/hour"),
        "promo": env("THROTTLE_PROMO", "20/min"),
        "sos": env("THROTTLE_SOS", "10/min"),
        "share": env("THROTTLE_SHARE", "60/min"),
    },
    "TEST_REQUEST_DEFAULT_FORMAT": "json",
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(env("JWT_ACCESS_MINUTES", "30"))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(env("JWT_REFRESH_DAYS", "14"))),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "SIGNING_KEY": env("JWT_SIGNING_KEY", SECRET_KEY),
    "AUTH_HEADER_TYPES": ("Bearer",),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "KaamNow API",
    "DESCRIPTION": (
        "On-demand local services marketplace (Lahore, Pakistan). Customers post service "
        "requests, nearby verified workers bid, both sides negotiate, and the customer books.\n\n"
        "All responses use the envelope `{success, data, message}` on success and "
        "`{success: false, error: {code, message, details}}` on failure."
    ),
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
    "SCHEMA_PATH_PREFIX": r"/api/v1",
    "ENUM_NAME_OVERRIDES": {
        "UserRoleEnum": "apps.accounts.models.User.Role",
        "PartyEnum": "apps.offers.models.Party",
        "PaymentMethodEnum": "apps.billing.models.Payment.Method",
        "OnlinePaymentMethodEnum": "apps.billing.serializers.ONLINE_METHOD_CHOICES",
        "PaymentStatusEnum": "apps.billing.models.Payment.Status",
        "SettlementMethodEnum": "apps.billing.models.WorkerSettlement.Method",
        "PayoutMethodEnum": "apps.billing.serializers.PAYOUT_METHOD_CHOICES",
        "CommissionReceivedMethodEnum": "apps.billing.serializers.RECEIVED_METHOD_CHOICES",
        "RefundMethodEnum": "apps.billing.models.Refund.Method",
        "PurchaseStatusEnum": "apps.billing.models.WorkerSubscription.Status",
        "ComplaintStatusEnum": "apps.support.models.Complaint.Status",
        "ComplaintStatusChangeEnum": "apps.support.serializers.STATUS_CHANGE_CHOICES",
        "BookingStatusEnum": "apps.jobs.models.Booking.Status",
        "BookingStatusChangeEnum": "apps.jobs.serializers.STATUS_CHANGE_CHOICES",
        "RecurringStatusEnum": "apps.recurring.models.RecurringJob.Status",
        "SosStatusEnum": "apps.safety.models.SosAlert.Status",
    },
}

# --- Redis, cache, Channels, Celery ------------------------------------------
REDIS_URL = env("REDIS_URL", "")

if REDIS_URL:
    CACHES = {"default": {"BACKEND": "django.core.cache.backends.redis.RedisCache", "LOCATION": REDIS_URL}}
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels_redis.core.RedisChannelLayer", "CONFIG": {"hosts": [REDIS_URL]}}
    }
else:
    # Single-process fallback for local development and tests.
    CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
    CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}

CELERY_BROKER_URL = env("CELERY_BROKER_URL", REDIS_URL or "memory://")
CELERY_RESULT_BACKEND = None
CELERY_TASK_ALWAYS_EAGER = env_bool("CELERY_TASK_ALWAYS_EAGER", not bool(REDIS_URL))
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_TIMEZONE = "Asia/Karachi"
CELERY_TASK_ACKS_LATE = True
CELERY_BEAT_SCHEDULE = {
    "expire-stale-requests": {"task": "apps.jobs.tasks.expire_stale_requests", "schedule": 15 * 60},
    "expire-stale-online-payments": {"task": "apps.billing.tasks.expire_stale_online_payments", "schedule": 10 * 60},
    "expire-subscriptions-and-featured": {"task": "apps.billing.tasks.expire_subscriptions_and_featured", "schedule": 30 * 60},
    "purge-old-locations": {"task": "apps.tracking.tasks.purge_old_locations", "schedule": 24 * 60 * 60},
    "purge-old-phone-codes": {"task": "apps.accounts.tasks.purge_old_phone_codes", "schedule": 6 * 60 * 60},
    "send-booking-reminders": {"task": "apps.reminders.tasks.send_booking_reminders", "schedule": 5 * 60},
    "create-recurring-visits": {"task": "apps.recurring.tasks.create_recurring_visits", "schedule": 15 * 60},
}

# --- Firebase Cloud Messaging -----------------------------------------------
FCM_PROJECT_ID = env("FCM_PROJECT_ID", "")

# Google Maps for the web app. A browser key is public by design (it ships to every browser):
# restrict it to the site's address and the Maps JavaScript API in Google Cloud. Empty = OpenStreetMap.
GOOGLE_MAPS_BROWSER_KEY = env("GOOGLE_MAPS_BROWSER_KEY", "")
# Path to the Firebase service-account JSON file (keep it outside the repo).
FCM_CREDENTIALS_FILE = env("FCM_CREDENTIALS_FILE", "")

# --- Web Push (browser notifications, no Firebase needed) ---------------------
# Generate once with `python manage.py generate_vapid_keys` (deploy/new-env.sh does it for you).
# Changing the keys unsubscribes every browser, so keep them for the life of the site.
WEBPUSH_VAPID_PUBLIC_KEY = env("WEBPUSH_VAPID_PUBLIC_KEY", "")
WEBPUSH_VAPID_PRIVATE_KEY = env("WEBPUSH_VAPID_PRIVATE_KEY", "")
# Contact the browser push services can use if something goes wrong.
WEBPUSH_SUBJECT = env("WEBPUSH_SUBJECT", "mailto:" + env("SUPPORT_EMAIL", "support@kaamnow.pk"))

# --- Payment gateways ---------------------------------------------------------
# Never commit real credentials. Leave blank to disable a gateway.
PAYMENT_GATEWAYS = {
    "jazzcash": {
        "MERCHANT_ID": env("JAZZCASH_MERCHANT_ID", ""),
        "PASSWORD": env("JAZZCASH_PASSWORD", ""),
        "INTEGRITY_SALT": env("JAZZCASH_INTEGRITY_SALT", ""),
        "CHECKOUT_URL": env(
            "JAZZCASH_CHECKOUT_URL",
            "https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/",
        ),
        "RETURN_URL": env("JAZZCASH_RETURN_URL", "https://api.kaamnow.pk/api/v1/payments/callbacks/jazzcash/"),
    },
    "easypaisa": {
        "STORE_ID": env("EASYPAISA_STORE_ID", ""),
        "HASH_KEY": env("EASYPAISA_HASH_KEY", ""),
        "USERNAME": env("EASYPAISA_USERNAME", ""),
        "PASSWORD": env("EASYPAISA_PASSWORD", ""),
        "ACCOUNT_NUM": env("EASYPAISA_ACCOUNT_NUM", ""),
        "CHECKOUT_URL": env("EASYPAISA_CHECKOUT_URL", "https://easypaystg.easypaisa.com.pk/easypay/Index.jsf"),
        "INQUIRY_URL": env(
            "EASYPAISA_INQUIRY_URL",
            "https://easypaystg.easypaisa.com.pk/easypay-service/rest/v4/inquire-transaction",
        ),
        "POSTBACK_URL": env("EASYPAISA_POSTBACK_URL", "https://api.kaamnow.pk/api/v1/payments/callbacks/easypaisa/"),
    },
}
ONLINE_PAYMENT_TTL_MINUTES = int(env("ONLINE_PAYMENT_TTL_MINUTES", "30"))

# --- CORS --------------------------------------------------------------------
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS", "")
# Needed for the Django admin login form when it is reached on another origin than the API host.
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS", "")
# Regexes for extra browser origins. In DEBUG, any localhost port is allowed so the
# Flutter web dev server (random port) can reach the API without extra setup.
CORS_ALLOWED_ORIGIN_REGEXES = env_list("CORS_ALLOWED_ORIGIN_REGEXES", "")
if DEBUG:
    CORS_ALLOWED_ORIGIN_REGEXES += [r"^http://localhost(:\d+)?$", r"^http://127\.0\.0\.1(:\d+)?$"]

# --- Client app configuration (served by GET /api/v1/app/config/) -----------
KAAMNOW_APP = {
    "MIN_ANDROID_VERSION": env("MIN_ANDROID_VERSION", "1.0.0"),
    "MIN_IOS_VERSION": env("MIN_IOS_VERSION", "1.0.0"),
    "MIN_WEB_VERSION": env("MIN_WEB_VERSION", "1.0.0"),
    "CITY_LATITUDE": float(env("CITY_LATITUDE", "31.5204")),
    "CITY_LONGITUDE": float(env("CITY_LONGITUDE", "74.3587")),
    "SUPPORT_EMAIL": env("SUPPORT_EMAIL", "support@kaamnow.pk"),
    "SUPPORT_PHONE": env("SUPPORT_PHONE", ""),
}

# --- Business configuration -----------------------------------------------
KAAMNOW = {
    # Upper bound (km) used to pre-filter workers before exact Haversine checks.
    "MAX_DISCOVERY_RADIUS_KM": float(env("MAX_DISCOVERY_RADIUS_KM", "50")),
    "DEFAULT_COMMISSION_PERCENT": env("DEFAULT_COMMISSION_PERCENT", "10.00"),
    "OTP_LENGTH": 6,
    "OTP_TTL_MINUTES": int(env("OTP_TTL_MINUTES", "15")),
    "OTP_MAX_ATTEMPTS": int(env("OTP_MAX_ATTEMPTS", "5")),
    "OTP_RESEND_COOLDOWN_SECONDS": int(env("OTP_RESEND_COOLDOWN_SECONDS", "60")),
    "MAX_NEGOTIATION_ROUNDS": int(env("MAX_NEGOTIATION_ROUNDS", "10")),
    "MIN_OFFER_PRICE": env("MIN_OFFER_PRICE", "100"),
    "MAX_OFFER_PRICE": env("MAX_OFFER_PRICE", "1000000"),
    # Live tracking / chat
    "LOCATION_RETENTION_DAYS": int(env("LOCATION_RETENTION_DAYS", "30")),
    "AVERAGE_CITY_SPEED_KMH": float(env("AVERAGE_CITY_SPEED_KMH", "25")),
    "CHAT_OPEN_HOURS_AFTER_COMPLETION": int(env("CHAT_OPEN_HOURS_AFTER_COMPLETION", "48")),
    # Open requests expire this many hours after their preferred time.
    "REQUEST_EXPIRY_HOURS": int(env("REQUEST_EXPIRY_HOURS", "24")),
    "MAX_FEATURED_PER_CATEGORY": int(env("MAX_FEATURED_PER_CATEGORY", "5")),
    # Geographic backend: "haversine" today, "postgis" planned.
    "GEO_BACKEND": env("GEO_BACKEND", "haversine"),
    # SMS codes for confirming phone numbers and resetting passwords.
    "PHONE_CODE_LENGTH": 6,
    "PHONE_CODE_TTL_MINUTES": int(env("PHONE_CODE_TTL_MINUTES", "10")),
    "PHONE_CODE_MAX_ATTEMPTS": int(env("PHONE_CODE_MAX_ATTEMPTS", "5")),
    "PHONE_CODE_RESEND_SECONDS": int(env("PHONE_CODE_RESEND_SECONDS", "60")),
    "PHONE_CODE_DAILY_LIMIT": int(env("PHONE_CODE_DAILY_LIMIT", "5")),
}

# --- SMS (phone verification and password reset codes) -----------------------
# "console" writes messages to the log (development). "twilio" sends real SMS through Twilio.
SMS_BACKEND = env("SMS_BACKEND", "console")
TWILIO_ACCOUNT_SID = env("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = env("TWILIO_AUTH_TOKEN", "")
# A Twilio phone number in +E.164 form, or an approved alphanumeric sender ID such as "KaamNow".
TWILIO_FROM = env("TWILIO_FROM", "")
# Customers and workers must confirm their number before posting jobs or sending offers. On by
# default once a real SMS service is set up; off with the console backend so local setups work.
PHONE_VERIFICATION_REQUIRED = env_bool("PHONE_VERIFICATION_REQUIRED", SMS_BACKEND != "console")

# --- Email (password reset) -------------------------------------------------
EMAIL_BACKEND = env("EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend")
EMAIL_HOST = env("EMAIL_HOST", "localhost")
EMAIL_PORT = int(env("EMAIL_PORT", "587"))
EMAIL_HOST_USER = env("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = env_bool("EMAIL_USE_TLS", True)
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", "KaamNow <no-reply@kaamnow.pk>")
PASSWORD_RESET_URL = env("PASSWORD_RESET_URL", "https://app.kaamnow.pk/reset-password?uid={uid}&token={token}")
# Link people share to invite friends; {code} is the inviter's code.
TRIP_SHARE_URL = env("TRIP_SHARE_URL", "https://app.kaamnow.pk/share/{token}")
INVITE_URL = env("INVITE_URL", "https://app.kaamnow.pk/register?ref={code}")

# --- Security hardening -----------------------------------------------------
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = env_bool("SECURE_SSL_REDIRECT", True)
    # Container health checks call the API over plain HTTP from inside the server.
    SECURE_REDIRECT_EXEMPT = [r"^api/v1/health/$"]
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(env("SECURE_HSTS_SECONDS", "31536000"))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": env("LOG_LEVEL", "INFO")},
}
