from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import mixins, status, viewsets
from rest_framework.response import Response

from . import services
from .models import Complaint
from .serializers import ComplaintCreateSerializer, ComplaintSerializer


@extend_schema_view(list=extend_schema(tags=["complaints"]), retrieve=extend_schema(tags=["complaints"]))
class ComplaintViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Customers and workers report problems; they only ever see their own complaints."""

    serializer_class = ComplaintSerializer
    filterset_fields = ["status", "category", "booking"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Complaint.objects.none()
        return Complaint.objects.filter(raised_by=self.request.user)

    @extend_schema(tags=["complaints"], request=ComplaintCreateSerializer, responses={201: ComplaintSerializer})
    def create(self, request):
        serializer = ComplaintCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        complaint = services.create_complaint(request.user, **serializer.validated_data)
        return Response(ComplaintSerializer(complaint).data, status=status.HTTP_201_CREATED)
