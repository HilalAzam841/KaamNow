from django.shortcuts import get_object_or_404
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import WorkerProfile
from apps.common.permissions import IsCustomer, IsPlatformAdmin, IsWorker
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.jobs.serializers import BookingSerializer
from apps.portfolio.serializers import HideSerializer

from . import services
from .models import ServicePackage
from .serializers import AdminPackageSerializer, BookPackageSerializer, MyPackageSerializer, PackageSerializer


def _ctx(request):
    return {"request": request}


class MyPackagesView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["packages"], responses={200: MyPackageSerializer(many=True)},
                   summary="Your fixed-price packages, including paused and hidden ones.")
    def get(self, request):
        packages = ServicePackage.objects.filter(worker=request.user.worker_profile).select_related("category")
        return Response(MyPackageSerializer(packages, many=True, context=_ctx(request)).data)

    @extend_schema(tags=["packages"], request=MyPackageSerializer, responses={201: MyPackageSerializer},
                   summary="Add a fixed-price package (up to 10) for a service you offer.")
    def post(self, request):
        s = MyPackageSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        package = services.create_package(request.user.worker_profile, **s.validated_data)
        return Response(MyPackageSerializer(package, context=_ctx(request)).data, status=status.HTTP_201_CREATED)


class MyPackageDetailView(APIView):
    permission_classes = [IsWorker]

    def _package(self, request, pk):
        return get_object_or_404(ServicePackage, pk=pk, worker=request.user.worker_profile)

    @extend_schema(tags=["packages"], request=MyPackageSerializer, responses={200: MyPackageSerializer},
                   summary="Change a package, or pause it with is_active false.")
    def patch(self, request, pk):
        package = self._package(request, pk)
        s = MyPackageSerializer(package, data=request.data, partial=True)
        s.is_valid(raise_exception=True)
        package = services.update_package(package, **s.validated_data)
        return Response(MyPackageSerializer(package, context=_ctx(request)).data)

    @extend_schema(tags=["packages"], responses={204: None},
                   summary="Delete a package. Bookings made from it are kept.")
    def delete(self, request, pk):
        self._package(request, pk).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class WorkerPackagesView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["packages"], responses={200: PackageSerializer(many=True)},
                   summary="A verified worker's packages that can be booked now.")
    def get(self, request, pk):
        worker = get_object_or_404(WorkerProfile, pk=pk, verification_status=WorkerProfile.VerificationStatus.VERIFIED,
                                   user__is_active=True)
        packages = services.public_packages().filter(worker=worker)
        return Response(PackageSerializer(packages, many=True, context=_ctx(request)).data)


@extend_schema(tags=["packages"], parameters=[
    OpenApiParameter("category", OpenApiTypes.INT, description="Only this service category."),
    OpenApiParameter("latitude", OpenApiTypes.DOUBLE, description="With longitude: only workers who cover this place."),
    OpenApiParameter("longitude", OpenApiTypes.DOUBLE),
    OpenApiParameter("max_price", OpenApiTypes.NUMBER),
])
class PackageListView(generics.ListAPIView):
    """Fixed-price packages to book straight away, best workers first."""

    permission_classes = [AllowAny]
    serializer_class = PackageSerializer

    def get_queryset(self):
        from decimal import Decimal, InvalidOperation

        qs = services.public_packages().order_by("-worker__level_rank", "-worker__average_rating", "price", "id")
        params = self.request.query_params
        try:
            if params.get("category"):
                qs = qs.filter(category_id=int(params["category"]))
            if params.get("max_price"):
                qs = qs.filter(price__lte=Decimal(params["max_price"]))
            lat, lng = params.get("latitude"), params.get("longitude")
            if lat and lng:
                lat, lng = float(lat), float(lng)
                if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                    return qs.none()
                return services.in_area(qs[:500], lat, lng)
        except (ValueError, InvalidOperation):
            return qs.none()
        return qs


class PackageDetailView(generics.RetrieveAPIView):
    permission_classes = [AllowAny]
    serializer_class = PackageSerializer

    def get_queryset(self):
        return services.public_packages()

    @extend_schema(tags=["packages"], summary="One package that can be booked now.")
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class BookPackageView(APIView):
    permission_classes = [IsCustomer]
    throttle_scope = "offers"

    @extend_schema(tags=["packages"], request=BookPackageSerializer, responses={201: BookingSerializer},
                   summary="Book a package at its fixed price. The worker must be free then and cover the address.")
    def post(self, request, pk):
        package = get_object_or_404(ServicePackage, pk=pk)
        s = BookPackageSerializer(data=request.data, context=_ctx(request))
        s.is_valid(raise_exception=True)
        booking = services.book_package(request.user, package, **s.validated_data)
        return Response(BookingSerializer(booking, context=_ctx(request)).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["admin"])
class AdminPackageViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Every worker package, newest first, to check and hide anything unsuitable."""

    permission_classes = [IsPlatformAdmin]
    serializer_class = AdminPackageSerializer
    filterset_fields = ["is_hidden", "is_active", "worker", "category"]

    def get_queryset(self):
        return ServicePackage.objects.select_related("worker__user", "category", "hidden_by").order_by("-created_at")

    @extend_schema(request=HideSerializer, responses={200: AdminPackageSerializer})
    @action(detail=True, methods=["post"])
    def hide(self, request, pk=None):
        s = HideSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        package = services.hide(self.get_object(), request.user, s.validated_data["reason"])
        audit(request.user, AuditLog.Action.PACKAGE_MODERATED, package, request, hidden=True,
              reason=package.hidden_reason, worker=package.worker_id)
        return Response(AdminPackageSerializer(package, context=_ctx(request)).data)

    @extend_schema(request=None, responses={200: AdminPackageSerializer})
    @action(detail=True, methods=["post"])
    def unhide(self, request, pk=None):
        package = services.unhide(self.get_object(), request.user)
        audit(request.user, AuditLog.Action.PACKAGE_MODERATED, package, request, hidden=False,
              worker=package.worker_id)
        return Response(AdminPackageSerializer(package, context=_ctx(request)).data)
