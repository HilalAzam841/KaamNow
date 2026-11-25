from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import WorkerProfile
from apps.common.permissions import IsPlatformAdmin, IsWorker
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from . import services
from .models import PortfolioPhoto
from .serializers import (
    AdminPortfolioPhotoSerializer,
    HideSerializer,
    MyPortfolioPhotoSerializer,
    PortfolioPhotoSerializer,
    PortfolioUpdateSerializer,
    PortfolioUploadSerializer,
    ReorderSerializer,
)


def _ctx(request):
    return {"request": request}


class MyPortfolioView(APIView):
    permission_classes = [IsWorker]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    @extend_schema(tags=["portfolio"], responses={200: MyPortfolioPhotoSerializer(many=True)},
                   summary="Your work photos in order, including any an admin hid.")
    def get(self, request):
        photos = PortfolioPhoto.objects.filter(worker=request.user.worker_profile).select_related("category")
        return Response(MyPortfolioPhotoSerializer(photos, many=True, context=_ctx(request)).data)

    @extend_schema(tags=["portfolio"], request={"multipart/form-data": PortfolioUploadSerializer},
                   responses={201: MyPortfolioPhotoSerializer},
                   summary="Add a photo of your work (up to 12). Location and camera data are removed.")
    def post(self, request):
        s = PortfolioUploadSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        photo = services.add_photo(request.user.worker_profile, **s.validated_data)
        return Response(MyPortfolioPhotoSerializer(photo, context=_ctx(request)).data, status=status.HTTP_201_CREATED)


class MyPortfolioPhotoView(APIView):
    permission_classes = [IsWorker]

    def _photo(self, request, pk):
        return get_object_or_404(PortfolioPhoto, pk=pk, worker=request.user.worker_profile)

    @extend_schema(tags=["portfolio"], request=PortfolioUpdateSerializer, responses={200: MyPortfolioPhotoSerializer},
                   summary="Change a photo's caption or service.")
    def patch(self, request, pk):
        photo = self._photo(request, pk)
        s = PortfolioUpdateSerializer(data=request.data, partial=True)
        s.is_valid(raise_exception=True)
        photo = services.update_photo(photo, s.validated_data)
        return Response(MyPortfolioPhotoSerializer(photo, context=_ctx(request)).data)

    @extend_schema(tags=["portfolio"], responses={204: None}, summary="Delete a photo (the file too).")
    def delete(self, request, pk):
        services.delete_photo(self._photo(request, pk))
        return Response(status=status.HTTP_204_NO_CONTENT)


class MyPortfolioReorderView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["portfolio"], request=ReorderSerializer, responses={200: MyPortfolioPhotoSerializer(many=True)},
                   summary="Put your photos in a new order. Send every photo id once.")
    def post(self, request):
        s = ReorderSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        photos = services.reorder(request.user.worker_profile, s.validated_data["ids"])
        return Response(MyPortfolioPhotoSerializer(photos, many=True, context=_ctx(request)).data)


class WorkerPortfolioView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["portfolio"], responses={200: PortfolioPhotoSerializer(many=True)},
                   summary="A verified worker's work photos (hidden ones are left out).")
    def get(self, request, pk):
        worker = get_object_or_404(WorkerProfile, pk=pk, verification_status=WorkerProfile.VerificationStatus.VERIFIED,
                                   user__is_active=True)
        return Response(PortfolioPhotoSerializer(services.visible_photos(worker), many=True, context=_ctx(request)).data)


@extend_schema(tags=["admin"])
class AdminPortfolioPhotoViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Every portfolio photo, newest first, to check and hide anything unsuitable."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminPortfolioPhotoSerializer
    filterset_fields = ["is_hidden", "worker"]

    def get_queryset(self):
        return PortfolioPhoto.objects.select_related("worker__user", "category", "hidden_by").order_by("-created_at")

    @extend_schema(request=HideSerializer, responses={200: AdminPortfolioPhotoSerializer})
    @action(detail=True, methods=["post"])
    def hide(self, request, pk=None):
        s = HideSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        photo = services.hide(self.get_object(), request.user, s.validated_data["reason"])
        audit(request.user, AuditLog.Action.PORTFOLIO_MODERATED, photo, request, hidden=True,
              reason=photo.hidden_reason, worker=photo.worker_id)
        return Response(AdminPortfolioPhotoSerializer(photo, context=_ctx(request)).data)

    @extend_schema(request=None, responses={200: AdminPortfolioPhotoSerializer})
    @action(detail=True, methods=["post"])
    def unhide(self, request, pk=None):
        photo = services.unhide(self.get_object(), request.user)
        audit(request.user, AuditLog.Action.PORTFOLIO_MODERATED, photo, request, hidden=False, worker=photo.worker_id)
        return Response(AdminPortfolioPhotoSerializer(photo, context=_ctx(request)).data)
