from drf_spectacular.utils import extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.common.permissions import IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from . import services
from .models import NoShowReport
from .serializers import AdminNoShowSerializer, ReviewNoShowSerializer


@extend_schema(tags=["admin"])
class AdminNoShowViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """No-show reports. Each row shows how many no-shows the reported person has in total."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminNoShowSerializer
    filterset_fields = ["side", "review"]

    def get_queryset(self):
        return NoShowReport.objects.select_related("booking__request", "reported_by", "against")

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        if getattr(self, "swagger_fake_view", False):
            return ctx
        ids = set(self.filter_queryset(self.get_queryset()).values_list("against_id", flat=True)[:500])
        ctx["counts"] = services.no_show_counts(ids)
        return ctx

    @extend_schema(request=ReviewNoShowSerializer, responses={200: AdminNoShowSerializer})
    @action(detail=True, methods=["post"])
    def review(self, request, pk=None):
        report = self.get_object()
        serializer = ReviewNoShowSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        report = services.review_no_show(report, request.user, **serializer.validated_data)
        audit(request.user, AuditLog.Action.NO_SHOW_REVIEWED, report, request, review=report.review,
              booking=report.booking_id)
        ctx = {"counts": services.no_show_counts([report.against_id])}
        return Response(AdminNoShowSerializer(report, context=ctx).data)
