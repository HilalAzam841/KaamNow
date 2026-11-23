from rest_framework import serializers

from .models import ServiceCategory, WorkerService


class ServiceCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceCategory
        fields = ["id", "name", "slug", "description", "icon", "is_active", "sort_order", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]
        extra_kwargs = {"slug": {"required": False}}

    def validate_name(self, value):
        value = value.strip()
        qs = ServiceCategory.objects.filter(name__iexact=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("A category with this name already exists.")
        return value


class WorkerServiceSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    worker_id = serializers.IntegerField(source="worker.id", read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    worker_rating = serializers.DecimalField(source="worker.average_rating", max_digits=3, decimal_places=2, read_only=True)
    worker_completed_jobs = serializers.IntegerField(source="worker.completed_jobs_count", read_only=True)
    worker_experience_years = serializers.IntegerField(source="worker.experience_years", read_only=True)
    worker_is_verified = serializers.BooleanField(source="worker.is_verified", read_only=True)
    worker_service_area = serializers.CharField(source="worker.service_area", read_only=True)

    class Meta:
        model = WorkerService
        fields = [
            "id", "category", "category_name", "description", "starting_price", "is_active",
            "worker_id", "worker_name", "worker_rating", "worker_completed_jobs", "worker_experience_years",
            "worker_is_verified", "worker_service_area", "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_category(self, category):
        if not category.is_active:
            raise serializers.ValidationError("This category is not active.")
        return category

    def validate(self, attrs):
        request = self.context["request"]
        category = attrs.get("category")
        if self.instance is None and category is not None:
            if WorkerService.objects.filter(worker__user=request.user, category=category).exists():
                raise serializers.ValidationError({"category": "You already offer this service."})
        if self.instance is not None and category is not None and category != self.instance.category:
            raise serializers.ValidationError({"category": "Category cannot be changed. Add a new service instead."})
        return attrs
