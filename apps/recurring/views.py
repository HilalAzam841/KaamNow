from django.http import Http404
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.common.permissions import IsCustomer, IsWorker

from . import services
from .models import RecurringJob
from .serializers import (
    RecurringFromBookingSerializer,
    RecurringJobForWorkerSerializer,
    RecurringJobSerializer,
    RecurringUpdateSerializer,
)


@extend_schema_view(
    list=extend_schema(
        summary="Your repeating jobs. Customers see their own; workers see the ones they are the usual worker for.",
        parameters=[OpenApiParameter("status", enum=["active", "paused", "cancelled"])]),
    retrieve=extend_schema(summary="One repeating job."),
)
@extend_schema(tags=["recurring"])
class RecurringJobViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = RecurringJobSerializer
    queryset = RecurringJob.objects.none()

    def _is_worker(self):
        user = self.request.user
        return getattr(user, "role", None) == "worker" and hasattr(user, "worker_profile")

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return RecurringJob.objects.none()
        user = self.request.user
        qs = RecurringJob.objects.select_related("category", "customer", "worker__user")
        if self._is_worker():
            qs = qs.filter(worker=user.worker_profile).exclude(status=RecurringJob.Status.CANCELLED)
        elif getattr(user, "role", None) == "customer":
            qs = qs.filter(customer=user)
        else:
            return RecurringJob.objects.none()
        wanted = self.request.query_params.get("status")
        if wanted in RecurringJob.Status.values:
            qs = qs.filter(status=wanted)
        return qs

    def get_serializer_class(self):
        if self._is_worker():
            return RecurringJobForWorkerSerializer
        return RecurringJobSerializer

    def _out(self, plan, code=status.HTTP_200_OK):
        return Response(RecurringJobSerializer(plan, context={"request": self.request}).data, status=code)

    @extend_schema(request=RecurringFromBookingSerializer, responses={201: RecurringJobSerializer},
                   summary="Repeat a job with the same worker every week, every two weeks or every month.")
    @action(detail=False, methods=["post"], url_path="from-booking", permission_classes=[IsCustomer])
    def from_booking(self, request):
        s = RecurringFromBookingSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        booking = s.validated_data["booking"]
        if booking.customer_id != request.user.pk:
            # Same answer as a booking that does not exist: do not reveal other people's bookings.
            raise Http404
        plan = services.create_from_booking(booking, request.user, frequency=s.validated_data["frequency"],
                                            first_visit=s.validated_data["first_visit"])
        return self._out(plan, status.HTTP_201_CREATED)

    @extend_schema(request=RecurringUpdateSerializer, responses={200: RecurringJobSerializer},
                   summary="Change how often it repeats, move the next visit, or change the budget.")
    def partial_update(self, request, pk=None):
        if not IsCustomer().has_permission(request, self):
            self.permission_denied(request, message=IsCustomer.message)
        plan = self.get_object()
        s = RecurringUpdateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return self._out(services.update(plan, request.user, s.validated_data))

    def _customer_action(self, request, fn):
        return self._out(fn(self.get_object(), request.user))

    @extend_schema(request=None, responses={200: RecurringJobSerializer}, summary="Pause: no visits until resumed.")
    @action(detail=True, methods=["post"], permission_classes=[IsCustomer])
    def pause(self, request, pk=None):
        return self._customer_action(request, services.pause)

    @extend_schema(request=None, responses={200: RecurringJobSerializer},
                   summary="Resume. Visits missed while paused are skipped.")
    @action(detail=True, methods=["post"], permission_classes=[IsCustomer])
    def resume(self, request, pk=None):
        return self._customer_action(request, services.resume)

    @extend_schema(request=None, responses={200: RecurringJobSerializer},
                   summary="Stop repeating. Jobs already posted are not cancelled.")
    @action(detail=True, methods=["post"], permission_classes=[IsCustomer])
    def cancel(self, request, pk=None):
        return self._customer_action(request, services.cancel)

    @extend_schema(request=None, responses={200: RecurringJobSerializer}, summary="Skip the next visit only.")
    @action(detail=True, methods=["post"], url_path="skip-next", permission_classes=[IsCustomer])
    def skip_next(self, request, pk=None):
        return self._customer_action(request, services.skip_next)

    @extend_schema(request=None, responses={200: RecurringJobForWorkerSerializer},
                   summary="Worker: stop being the usual worker. Future visits go to every free worker nearby.")
    @action(detail=True, methods=["post"], permission_classes=[IsWorker])
    def leave(self, request, pk=None):
        plan = services.leave(self.get_object(), request.user.worker_profile)
        return Response(RecurringJobForWorkerSerializer(plan).data)
