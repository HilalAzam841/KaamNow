from django.db import IntegrityError, transaction
from django.utils.translation import gettext as _
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import BusinessRuleError
from apps.common.permissions import IsCustomer

from . import services
from .models import FavouriteWorker
from .serializers import AddFavouriteSerializer, FavouriteWorkerSerializer


def _out(request, workers):
    ctx = {"request": request, "favourite_ids": services.favourite_ids(request.user)}
    return FavouriteWorkerSerializer(workers, many=True, context=ctx).data


class FavouritesView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["favourites"], responses={200: FavouriteWorkerSerializer(many=True)},
                   summary="Workers you saved, newest first.")
    def get(self, request):
        return Response(_out(request, services.favourites(request.user)))

    @extend_schema(tags=["favourites"], request=AddFavouriteSerializer, responses={201: FavouriteWorkerSerializer},
                   summary="Save a worker to book again. Saving one twice is fine.")
    def post(self, request):
        serializer = AddFavouriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        worker = serializer.validated_data["worker"]
        if worker.user_id == request.user.pk:
            raise BusinessRuleError(_("You cannot save yourself."))
        if not FavouriteWorker.objects.filter(customer=request.user, worker=worker).exists():
            if FavouriteWorker.objects.filter(customer=request.user).count() >= services.MAX_FAVOURITES:
                raise BusinessRuleError(_("You can save up to 100 workers. Remove one first."))
            try:
                with transaction.atomic():
                    FavouriteWorker.objects.create(customer=request.user, worker=worker)
            except IntegrityError:
                pass  # saved at the same moment by another request
        ctx = {"request": request, "favourite_ids": {worker.pk}}
        return Response(FavouriteWorkerSerializer(worker, context=ctx).data, status=status.HTTP_201_CREATED)


class FavouriteDetailView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["favourites"], responses={204: None}, summary="Remove a saved worker.")
    def delete(self, request, worker_id):
        FavouriteWorker.objects.filter(customer=request.user, worker_id=worker_id).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class RecentWorkersView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["favourites"], responses={200: FavouriteWorkerSerializer(many=True)},
                   summary="Workers who did a job for you, most recent first, to book again.")
    def get(self, request):
        return Response(_out(request, services.recent_workers(request.user)))
