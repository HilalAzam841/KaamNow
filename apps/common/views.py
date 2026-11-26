from django.conf import settings
from django.db import connection
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@extend_schema(tags=["health"], responses={200: dict})
@api_view(["GET"])
@permission_classes([AllowAny])
@throttle_classes([])
def health(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    return Response({"status": "ok"})


def _payment_methods():
    from apps.billing.gateways import get_gateway
    from apps.billing.models import Payment

    methods = [{"code": Payment.Method.CASH, "label": Payment.Method.CASH.label, "available": True}]
    for method in (Payment.Method.JAZZCASH, Payment.Method.EASYPAISA):
        methods.append({"code": method, "label": method.label, "available": get_gateway(method).is_configured})
    return methods


AppConfigSerializer = inline_serializer(
    name="AppConfig",
    fields={
        "api_version": serializers.CharField(),
        "min_supported_version": serializers.DictField(child=serializers.CharField()),
        "currency": serializers.CharField(),
        "city": inline_serializer(
            name="AppConfigCity",
            fields={
                "name": serializers.CharField(),
                "latitude": serializers.FloatField(),
                "longitude": serializers.FloatField(),
            },
        ),
        "emergency": inline_serializer(
            name="AppConfigEmergency",
            fields={"enabled": serializers.BooleanField(), "fee": serializers.CharField()},
        ),
        "cancellation": inline_serializer(
            name="AppConfigCancellation",
            fields={"enabled": serializers.BooleanField(), "free_minutes": serializers.IntegerField(),
                    "window_minutes": serializers.IntegerField(), "late_fee": serializers.CharField(),
                    "on_the_way_fee": serializers.CharField()},
        ),
        "tips": inline_serializer(
            name="AppConfigTips",
            fields={"enabled": serializers.BooleanField(), "min": serializers.CharField(),
                    "max": serializers.CharField(), "window_days": serializers.IntegerField(),
                    "suggestions": serializers.ListField(child=serializers.CharField())},
        ),
        "offer_price": inline_serializer(
            name="AppConfigOfferPrice", fields={"min": serializers.CharField(), "max": serializers.CharField()}
        ),
        "payment_methods": serializers.ListField(child=serializers.DictField()),
        "push_enabled": serializers.BooleanField(),
        "web_push": inline_serializer(
            name="AppConfigWebPush",
            fields={"enabled": serializers.BooleanField(), "public_key": serializers.CharField()},
        ),
        "phone_verification": inline_serializer(
            name="AppConfigPhoneVerification",
            fields={"required": serializers.BooleanField(), "sms_available": serializers.BooleanField()},
        ),
        "maps": inline_serializer(
            name="AppConfigMaps",
            fields={"provider": serializers.ChoiceField(choices=["google", "openstreetmap"]),
                    "google_browser_key": serializers.CharField(
                        help_text="Google Maps key for the web app. Public by design: restrict it to your "
                        "site's address in Google Cloud. Empty when not set up.")},
        ),
        "websocket_path": serializers.CharField(),
        "support": inline_serializer(
            name="AppConfigSupport",
            fields={"email": serializers.CharField(), "phone": serializers.CharField()},
        ),
    },
)


@extend_schema(
    tags=["app"],
    responses={200: AppConfigSerializer},
    summary="Public bootstrap config for web and mobile clients (no login needed).",
    description="Call on app start. Clients older than `min_supported_version` for their platform "
    "should ask the user to update. `payment_methods[].available` is false until a gateway is configured.",
)
@api_view(["GET"])
@permission_classes([AllowAny])
def app_config(request):
    from apps.billing.models import PlatformSettings
    from apps.notifications import fcm, webpush
    from apps.common import sms
    from apps.tips.models import MIN_TIP
    from apps.tips.services import suggestions as tip_suggestions

    platform = PlatformSettings.load()
    app = settings.KAAMNOW_APP
    return Response(
        {
            "api_version": "v1",
            "min_supported_version": {
                "android": app["MIN_ANDROID_VERSION"],
                "ios": app["MIN_IOS_VERSION"],
                "web": app["MIN_WEB_VERSION"],
            },
            "currency": "PKR",
            "city": {"name": "Lahore", "latitude": app["CITY_LATITUDE"], "longitude": app["CITY_LONGITUDE"]},
            "emergency": {"enabled": platform.emergency_enabled, "fee": f"{platform.emergency_fee:.2f}"},
            "cancellation": {
                "enabled": platform.cancellation_fee_enabled,
                "free_minutes": platform.cancellation_free_minutes,
                "window_minutes": platform.cancellation_window_minutes,
                "late_fee": f"{platform.late_cancellation_fee:.2f}",
                "on_the_way_fee": f"{platform.on_the_way_cancellation_fee:.2f}",
            },
            "tips": {
                "enabled": platform.tips_enabled,
                "min": f"{MIN_TIP:.2f}",
                "max": f"{platform.tip_max_amount:.2f}",
                "window_days": platform.tip_window_days,
                "suggestions": [f"{x:.2f}" for x in tip_suggestions(platform)],
            },
            "offer_price": {
                "min": settings.KAAMNOW["MIN_OFFER_PRICE"],
                "max": settings.KAAMNOW["MAX_OFFER_PRICE"],
            },
            "payment_methods": _payment_methods(),
            "push_enabled": fcm.is_configured(),
            "web_push": {"enabled": webpush.is_configured(), "public_key": webpush.public_key()},
            "phone_verification": {"required": settings.PHONE_VERIFICATION_REQUIRED, "sms_available": sms.is_available()},
            "maps": {
                "provider": "google" if settings.GOOGLE_MAPS_BROWSER_KEY else "openstreetmap",
                "google_browser_key": settings.GOOGLE_MAPS_BROWSER_KEY,
            },
            "websocket_path": "/ws/bookings/{booking_id}/?token={access_token}",
            "support": {"email": app["SUPPORT_EMAIL"], "phone": app["SUPPORT_PHONE"]},
        }
    )
