from django.http import Http404
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema, inline_serializer
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsPlatformAdmin, IsWorker
from apps.jobs.models import ServiceRequest
from apps.jobs.serializers import BookingSerializer

from . import services
from .models import WorkerOffer
from .serializers import (
    NegotiateSerializer,
    NegotiationSerializer,
    OfferAcceptSerializer,
    OfferCreateSerializer,
    OfferRejectSerializer,
    OfferUpdateSerializer,
    WorkerOfferSerializer,
)

ORDERINGS = {
    "price": "current_price",
    "-price": "-current_price",
    "rating": "-worker__average_rating",
    "distance": "distance_km",
    "experience": "-worker__experience_years",
    "completed_jobs": "-worker__completed_jobs_count",
    "eta": "estimated_arrival_minutes",
}


def offer_queryset():
    return WorkerOffer.objects.select_related("request", "worker__user", "booking").prefetch_related(
        "negotiations", "worker__services__category"
    )


def get_offer_for_participant(request, pk):
    """Only the request's customer, the offering worker, or an admin may see an offer."""
    offer = get_object_or_404(offer_queryset(), pk=pk)
    user = request.user
    if IsPlatformAdmin().has_permission(request, None):
        return offer
    if user.pk in (offer.request.customer_id, offer.worker.user_id):
        return offer
    raise Http404


class RequestOffersView(generics.GenericAPIView):
    """GET: compare offers on a request. POST: worker submits an offer."""

    serializer_class = WorkerOfferSerializer
    queryset = WorkerOffer.objects.none()  # for schema generation only

    def get_throttles(self):
        if self.request.method == "POST":
            self.throttle_scope = "offers"
        return super().get_throttles()

    def _service_request(self):
        return get_object_or_404(ServiceRequest.objects.select_related("customer"), pk=self.kwargs["request_id"])

    @extend_schema(
        tags=["offers"],
        parameters=[
            OpenApiParameter("ordering", str, enum=list(ORDERINGS.keys())),
            OpenApiParameter("status", str),
        ],
        responses={200: WorkerOfferSerializer(many=True)},
        summary="Customer: compare all offers (price, rating, jobs, distance, experience, verification). "
        "Worker: see your own offer.",
    )
    def get(self, request, request_id):
        service_request = self._service_request()
        qs = offer_queryset().filter(request=service_request)
        user = request.user
        if IsPlatformAdmin().has_permission(request, self) or service_request.customer_id == user.pk:
            pass
        elif user.role == "worker" and hasattr(user, "worker_profile"):
            qs = qs.filter(worker=user.worker_profile)
        else:
            raise Http404
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"])
        qs = qs.order_by(ORDERINGS.get(request.query_params.get("ordering"), "current_price"), "created_at")
        page = self.paginate_queryset(qs)
        return self.get_paginated_response(WorkerOfferSerializer(page, many=True).data)

    @extend_schema(tags=["offers"], request=OfferCreateSerializer, responses={201: WorkerOfferSerializer})
    def post(self, request, request_id):
        if not IsWorker().has_permission(request, self):
            return Response({"detail": IsWorker.message}, status=status.HTTP_403_FORBIDDEN)
        service_request = self._service_request()
        serializer = OfferCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        offer = services.create_offer(request.user.worker_profile, service_request, **serializer.validated_data)
        return Response(WorkerOfferSerializer(offer_queryset().get(pk=offer.pk)).data, status=status.HTTP_201_CREATED)


class OfferDetailView(APIView):
    @extend_schema(tags=["offers"], responses={200: WorkerOfferSerializer})
    def get(self, request, pk):
        return Response(WorkerOfferSerializer(get_offer_for_participant(request, pk)).data)

    @extend_schema(tags=["offers"], request=OfferUpdateSerializer, responses={200: WorkerOfferSerializer})
    def patch(self, request, pk):
        offer = get_offer_for_participant(request, pk)
        serializer = OfferUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        offer = services.update_offer(offer, request.user, **serializer.validated_data)
        return Response(WorkerOfferSerializer(offer_queryset().get(pk=offer.pk)).data)


class OfferAcceptView(APIView):
    @extend_schema(
        tags=["offers"], request=OfferAcceptSerializer, responses={201: BookingSerializer},
        summary="Customer accepts the offer at its current price; creates the booking atomically.",
    )
    def post(self, request, pk):
        offer = get_offer_for_participant(request, pk)
        serializer = OfferAcceptSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        booking = services.accept_offer(offer, request.user, message=serializer.validated_data["message"])
        return Response(BookingSerializer(booking, context={"request": request}).data, status=status.HTTP_201_CREATED)


class OfferRejectView(APIView):
    @extend_schema(
        tags=["offers"], request=OfferRejectSerializer, responses={200: WorkerOfferSerializer},
        summary="Customer rejects an offer, or the worker withdraws it.",
    )
    def post(self, request, pk):
        offer = get_offer_for_participant(request, pk)
        serializer = OfferRejectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        offer = services.reject_offer(offer, request.user, serializer.validated_data["reason"])
        return Response(WorkerOfferSerializer(offer_queryset().get(pk=offer.pk)).data)


class OfferNegotiateView(APIView):
    def get_throttles(self):
        self.throttle_scope = "offers"
        return super().get_throttles()

    @extend_schema(
        tags=["offers"], request=NegotiateSerializer,
        responses={200: inline_serializer("NegotiateResponse", {
            "offer": WorkerOfferSerializer(), "booking": BookingSerializer(allow_null=True),
        })},
        summary="Counter-propose a price, or agree to the other party's latest price.",
    )
    def post(self, request, pk):
        offer = get_offer_for_participant(request, pk)
        serializer = NegotiateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        offer, booking = services.negotiate(offer, request.user, **serializer.validated_data)
        return Response({
            "offer": WorkerOfferSerializer(offer_queryset().get(pk=offer.pk)).data,
            "booking": BookingSerializer(booking, context={"request": request}).data if booking else None,
        })


class OfferNegotiationHistoryView(APIView):
    @extend_schema(tags=["offers"], responses={200: NegotiationSerializer(many=True)})
    def get(self, request, pk):
        offer = get_offer_for_participant(request, pk)
        return Response(NegotiationSerializer(offer.negotiations.all(), many=True).data)
