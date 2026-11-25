from django.db import transaction
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsCustomer, IsWorker

from . import services
from .models import TimeOff
from .serializers import (
    ScheduleSerializer,
    SlotQuerySerializer,
    SlotSerializer,
    TimeOffSerializer,
    WorkerSlotQuerySerializer,
    WorkerSlotSerializer,
)


def _worker(request):
    return request.user.worker_profile


class MyScheduleView(APIView):
    permission_classes = [IsWorker]

    def _data(self, worker):
        return ScheduleSerializer({"hours": worker.working_hours.all(),
                                   "time_off": services.upcoming_time_off(worker)}).data

    @extend_schema(tags=["workers"], responses={200: ScheduleSerializer},
                   summary="Your weekly working hours and upcoming time off.")
    def get(self, request):
        return Response(self._data(_worker(request)))

    @extend_schema(tags=["workers"], request=ScheduleSerializer, responses={200: ScheduleSerializer},
                   summary="Replace your weekly working hours. You are only matched with jobs inside them.")
    @transaction.atomic
    def put(self, request):
        serializer = ScheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        worker = _worker(request)
        services.replace_hours(worker, serializer.validated_data["hours"])
        return Response(self._data(worker))


class MyTimeOffView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["workers"], request=TimeOffSerializer, responses={201: TimeOffSerializer},
                   summary="Mark days off (holiday, leave). You are not matched with jobs on those days.")
    def post(self, request):
        serializer = TimeOffSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        off = serializer.save(worker=_worker(request))
        return Response(TimeOffSerializer(off).data, status=status.HTTP_201_CREATED)


class MyTimeOffDetailView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["workers"], responses={204: None}, summary="Remove a time off entry.")
    def delete(self, request, pk):
        get_object_or_404(TimeOff, pk=pk, worker=_worker(request)).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class WorkerSlotsView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(
        tags=["workers"], responses={200: WorkerSlotSerializer(many=True)},
        parameters=[OpenApiParameter("date", str, required=True, description="YYYY-MM-DD")],
        summary="One worker's two-hour slots on a day and whether they are free, to book them again.",
    )
    def get(self, request, pk):
        from apps.favourites.services import public_workers

        worker = get_object_or_404(public_workers(), pk=pk)
        q = WorkerSlotQuerySerializer(data=request.query_params)
        q.is_valid(raise_exception=True)
        slots = services.worker_day_slots(worker, q.validated_data["date"])
        return Response(WorkerSlotSerializer([{"start": s, "end": e, "free": f} for s, e, f in slots], many=True).data)


class SlotsView(APIView):
    @extend_schema(
        tags=["requests"], responses={200: SlotSerializer(many=True)},
        parameters=[OpenApiParameter("category", int, required=True), OpenApiParameter("latitude", float, required=True),
                    OpenApiParameter("longitude", float, required=True), OpenApiParameter("date", str, required=True,
                                                                                         description="YYYY-MM-DD")],
        summary="Two-hour time slots on a day, with how many matching workers nearby are free in each. "
                "Counts only, never who.",
    )
    def get(self, request):
        from apps.jobs.services import find_nearby_workers

        q = SlotQuerySerializer(data=request.query_params)
        q.is_valid(raise_exception=True)
        v = q.validated_data
        workers = find_nearby_workers(v["category"], v["latitude"], v["longitude"], exclude_user=request.user)
        slots = services.slots_with_free_workers(workers, v["date"])
        return Response(SlotSerializer([{"start": s, "end": e, "free_workers": n} for s, e, n in slots], many=True).data)
