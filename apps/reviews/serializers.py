from rest_framework import serializers

from apps.jobs.models import Booking

from .models import Review


class ReviewCreateSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all())
    rating = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")


class ReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.SerializerMethodField()
    category_name = serializers.CharField(source="booking.request.category.display_name", read_only=True)

    class Meta:
        model = Review
        fields = ["id", "booking", "worker", "rating", "comment", "customer_name", "category_name", "created_at"]
        read_only_fields = fields

    def get_customer_name(self, obj) -> str:
        # First name only for privacy.
        return obj.customer.full_name.split(" ")[0]
