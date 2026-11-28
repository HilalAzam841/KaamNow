from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import WorkerProfile
from apps.common.permissions import IsCustomer, IsPlatformAdmin
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit

from . import services
from .models import Review, ReviewPhoto
from .serializers import (
    AdminReviewSerializer,
    ModerationReasonSerializer,
    ReplySerializer,
    ReviewCreateSerializer,
    ReviewPhotoSerializer,
    ReviewPhotoUploadSerializer,
    ReviewSerializer,
)


def _public_reviews():
    return Review.objects.filter(is_visible=True).select_related(
        "customer", "worker__user", "booking__request__category"
    ).prefetch_related(Prefetch("photos", queryset=ReviewPhoto.objects.filter(is_hidden=False)))


class ReviewCreateView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["reviews"], request=ReviewCreateSerializer, responses={201: ReviewSerializer})
    def post(self, request):
        serializer = ReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        review = services.create_review(request.user, **serializer.validated_data)
        return Response(ReviewSerializer(review, context={"request": request}).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["reviews", "workers"],
               parameters=[OpenApiParameter("with_photos", bool, description="Only reviews with photos.")])
class WorkerReviewsView(generics.ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Review.objects.none()
        worker = get_object_or_404(WorkerProfile, pk=self.kwargs["pk"])
        qs = _public_reviews().filter(worker=worker)
        if self.request.query_params.get("with_photos") in ("1", "true"):
            qs = qs.filter(photos__is_hidden=False).distinct()
        return qs


@extend_schema(tags=["reviews"])
class ReviewViewSet(mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """A review: its author adds photos, the reviewed worker replies once."""

    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Review.objects.none()
        return _public_reviews()

    @extend_schema(request={"multipart/form-data": ReviewPhotoUploadSerializer}, responses={201: ReviewPhotoSerializer},
                   summary="Add a photo to your review (up to 3). Location and camera data are removed.")
    @action(detail=True, methods=["post"])
    def photos(self, request, pk=None):
        s = ReviewPhotoUploadSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        photo = services.add_photo(self.get_object(), request.user, s.validated_data["image"])
        return Response(ReviewPhotoSerializer(photo, context={"request": request}).data, status=201)

    @extend_schema(request=None, responses={204: None}, summary="Remove a photo from your review.")
    @action(detail=True, methods=["delete"], url_path=r"photos/(?P<photo_id>\d+)")
    def delete_photo(self, request, pk=None, photo_id=None):
        review = self.get_object()
        photo = get_object_or_404(ReviewPhoto, pk=photo_id, review=review)
        services.delete_photo(photo, request.user)
        return Response(status=204)

    @extend_schema(request=ReplySerializer, responses={200: ReviewSerializer},
                   summary="The reviewed worker replies in public, once. The customer is told.")
    @action(detail=True, methods=["post"])
    def reply(self, request, pk=None):
        s = ReplySerializer(data=request.data)
        s.is_valid(raise_exception=True)
        review = services.reply(self.get_object(), request.user, s.validated_data["reply"])
        return Response(ReviewSerializer(_public_reviews().get(pk=review.pk), context={"request": request}).data)


@extend_schema(tags=["admin"], parameters=[OpenApiParameter("with_photos", bool)])
class AdminReviewViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Every review, newest first. Hide abusive reviews, photos or replies (all audited)."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminReviewSerializer
    filterset_fields = ["is_visible", "worker", "customer", "rating"]

    def get_queryset(self):
        qs = Review.objects.select_related("customer", "worker__user").prefetch_related("photos")
        if self.request.query_params.get("with_photos") in ("1", "true"):
            qs = qs.filter(photos__isnull=False).distinct()
        return qs

    def _out(self, review):
        return Response(AdminReviewSerializer(self.get_queryset().get(pk=review.pk), context={"request": self.request}).data)

    @extend_schema(request=ModerationReasonSerializer, responses={200: AdminReviewSerializer},
                   summary="Hide a review (audited). It stops counting toward the worker's rating.")
    @action(detail=True, methods=["post"])
    def hide(self, request, pk=None):
        s = ModerationReasonSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        review = services.set_visible(self.get_object(), False)
        audit(request.user, AuditLog.Action.REVIEW_MODERATED, review, request, outcome="review_hidden",
              reason=s.validated_data["reason"])
        return self._out(review)

    @extend_schema(request=None, responses={200: AdminReviewSerializer}, summary="Show a hidden review again (audited).")
    @action(detail=True, methods=["post"])
    def unhide(self, request, pk=None):
        review = services.set_visible(self.get_object(), True)
        audit(request.user, AuditLog.Action.REVIEW_MODERATED, review, request, outcome="review_shown")
        return self._out(review)

    @extend_schema(request=ModerationReasonSerializer, responses={200: AdminReviewSerializer},
                   summary="Remove the worker's reply (audited). The worker can reply again.")
    @action(detail=True, methods=["post"], url_path="remove-reply")
    def remove_reply(self, request, pk=None):
        s = ModerationReasonSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        review = self.get_object()
        old = review.reply
        services.remove_reply(review)
        audit(request.user, AuditLog.Action.REVIEW_MODERATED, review, request, outcome="reply_removed",
              reason=s.validated_data["reason"], reply=old[:200])
        return self._out(review)

    @extend_schema(request=ModerationReasonSerializer, responses={200: AdminReviewSerializer},
                   summary="Hide one photo on a review (audited).")
    @action(detail=True, methods=["post"], url_path=r"photos/(?P<photo_id>\d+)/hide")
    def hide_photo(self, request, pk=None, photo_id=None):
        s = ModerationReasonSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        review = self.get_object()
        photo = get_object_or_404(ReviewPhoto, pk=photo_id, review=review)
        services.set_photo_hidden(photo, request.user, True, s.validated_data["reason"])
        audit(request.user, AuditLog.Action.REVIEW_MODERATED, review, request, outcome="photo_hidden",
              photo=photo.pk, reason=s.validated_data["reason"])
        return self._out(review)

    @extend_schema(request=None, responses={200: AdminReviewSerializer}, summary="Show a hidden photo again (audited).")
    @action(detail=True, methods=["post"], url_path=r"photos/(?P<photo_id>\d+)/unhide")
    def unhide_photo(self, request, pk=None, photo_id=None):
        review = self.get_object()
        photo = get_object_or_404(ReviewPhoto, pk=photo_id, review=review)
        services.set_photo_hidden(photo, request.user, False)
        audit(request.user, AuditLog.Action.REVIEW_MODERATED, review, request, outcome="photo_shown", photo=photo.pk)
        return self._out(review)
