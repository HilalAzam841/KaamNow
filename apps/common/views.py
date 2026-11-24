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
        "offer_price": inline_serializer(
            name="AppConfigOfferPrice", fields={"min": serializers.CharField(), "max": serializers.CharField()}
        ),
        "payment_methods": serializers.ListField(child=serializers.DictField()),
        "push_enabled": serializers.BooleanField(),
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
    from apps.notifications import fcm

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
            "offer_price": {
                "min": settings.KAAMNOW["MIN_OFFER_PRICE"],
                "max": settings.KAAMNOW["MAX_OFFER_PRICE"],
            },
            "payment_methods": _payment_methods(),
            "push_enabled": fcm.is_configured(),
            "websocket_path": "/ws/bookings/{booking_id}/?token={access_token}",
            "support": {"email": app["SUPPORT_EMAIL"], "phone": app["SUPPORT_PHONE"]},
        }
    )
