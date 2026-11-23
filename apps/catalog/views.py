import django_filters
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import permissions, viewsets
from rest_framework.exceptions import PermissionDenied

from apps.accounts.models import WorkerProfile
from apps.common.permissions import IsAdminOrReadOnly, IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from .models import ServiceCategory, WorkerService
from .serializers import ServiceCategorySerializer, WorkerServiceSerializer


@extend_schema_view(
    list=extend_schema(tags=["services"], summary="List service categories"),
    retrieve=extend_schema(tags=["services"]),
    create=extend_schema(tags=["services"], summary="Admin: create category"),
    partial_update=extend_schema(tags=["services"], summary="Admin: update / activate / deactivate category"),
)
class ServiceCategoryViewSet(viewsets.ModelViewSet):
    """Anyone can browse active categories; admins can create, update, activate and deactivate them."""

    serializer_class = ServiceCategorySerializer
    permission_classes = [IsAdminOrReadOnly]
    http_method_names = ["get", "post", "patch"]
    search_fields = ["name"]
    ordering_fields = ["sort_order", "name"]
    pagination_class = None

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [permissions.AllowAny()]
        return super().get_permissions()

    def get_queryset(self):
        qs = ServiceCategory.objects.all()
        user = self.request.user
        if not (user.is_authenticated and IsPlatformAdmin().has_permission(self.request, self)):
            qs = qs.filter(is_active=True)
        return qs

    def perform_create(self, serializer):
        category = serializer.save()
        audit(self.request.user, AuditLog.Action.CATEGORY_CHANGED, category, self.request, op="create",
              data=serializer.data)

    def perform_update(self, serializer):
        category = serializer.save()
        audit(self.request.user, AuditLog.Action.CATEGORY_CHANGED, category, self.request, op="update",
              changes={k: str(v) for k, v in serializer.validated_data.items()})


class WorkerServiceFilter(django_filters.FilterSet):
    category = django_filters.NumberFilter(field_name="category_id")
    min_rating = django_filters.NumberFilter(field_name="worker__average_rating", lookup_expr="gte")

    class Meta:
        model = WorkerService
        fields = ["category", "min_rating"]


@extend_schema_view(
    list=extend_schema(
        tags=["services"],
        summary="Browse worker service listings (verified workers only). Use ?mine=true as a worker for your own.",
        parameters=[OpenApiParameter("mine", bool)],
    ),
    create=extend_schema(tags=["services"], summary="Worker: add a service category you offer"),
    retrieve=extend_schema(tags=["services"]),
    partial_update=extend_schema(tags=["services"]),
    destroy=extend_schema(tags=["services"]),
)
class WorkerServiceViewSet(viewsets.ModelViewSet):
    serializer_class = WorkerServiceSerializer
    filterset_class = WorkerServiceFilter
    ordering_fields = ["starting_price", "worker__average_rating", "worker__completed_jobs_count"]
    http_method_names = ["get", "post", "patch", "delete"]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def _is_worker(self):
        user = self.request.user
        return user.is_authenticated and user.role == "worker" and hasattr(user, "worker_profile")

    def get_queryset(self):
        qs = WorkerService.objects.select_related("category", "worker__user")
        if getattr(self, "swagger_fake_view", False):
            return qs.none()
        mine = self.request.query_params.get("mine") in ("1", "true", "True")
        if self.action in ("list", "retrieve") and not (mine and self._is_worker()):
            return qs.filter(
                is_active=True,
                category__is_active=True,
                worker__verification_status=WorkerProfile.VerificationStatus.VERIFIED,
                worker__user__is_active=True,
                worker__user__is_suspended=False,
            ).order_by("-worker__average_rating", "id")
        if not self._is_worker():
            return qs.none()
        return qs.filter(worker__user=self.request.user)

    def perform_create(self, serializer):
        if not self._is_worker():
            raise PermissionDenied("Only service providers can add services.")
        serializer.save(worker=self.request.user.worker_profile)
