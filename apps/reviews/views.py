from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import WorkerProfile
from apps.common.permissions import IsCustomer

from . import services
from .models import Review
from .serializers import ReviewCreateSerializer, ReviewSerializer


class ReviewCreateView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["reviews"], request=ReviewCreateSerializer, responses={201: ReviewSerializer})
    def post(self, request):
        serializer = ReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        review = services.create_review(request.user, **serializer.validated_data)
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["reviews", "workers"])
class WorkerReviewsView(generics.ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Review.objects.none()
        worker = get_object_or_404(WorkerProfile, pk=self.kwargs["pk"])
        return Review.objects.filter(worker=worker, is_visible=True).select_related(
            "customer", "booking__request__category"
        )
