from decimal import Decimal

from rest_framework import serializers


class LocationUpdateSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=Decimal("-90"),
                                        max_value=Decimal("90"))
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=Decimal("-180"),
                                         max_value=Decimal("180"))
    accuracy_m = serializers.DecimalField(max_digits=7, decimal_places=2, min_value=Decimal("0"), required=False,
                                          allow_null=True)
    heading = serializers.DecimalField(max_digits=5, decimal_places=2, min_value=Decimal("0"),
                                       max_value=Decimal("360"), required=False, allow_null=True)
    speed_kmh = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0"),
                                         max_value=Decimal("300"), required=False, allow_null=True)


class LocationPointSerializer(serializers.Serializer):
    latitude = serializers.CharField()
    longitude = serializers.CharField()
    accuracy_m = serializers.CharField(allow_null=True)
    heading = serializers.CharField(allow_null=True)
    speed_kmh = serializers.CharField(allow_null=True)
    recorded_at = serializers.DateTimeField()
    distance_to_customer_km = serializers.FloatField()
    eta_minutes = serializers.IntegerField()
    booking_status = serializers.CharField()


class TrailPointSerializer(serializers.Serializer):
    latitude = serializers.CharField()
    longitude = serializers.CharField()
    recorded_at = serializers.DateTimeField()


class LiveLocationSerializer(serializers.Serializer):
    latest = LocationPointSerializer(allow_null=True)
    trail = TrailPointSerializer(many=True)
