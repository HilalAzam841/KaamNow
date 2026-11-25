from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsCustomer

from . import services
from .models import SavedAddress
from .serializers import SavedAddressSerializer


class AddressesView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["addresses"], responses={200: SavedAddressSerializer(many=True)},
                   summary="Your saved addresses, the default first.")
    def get(self, request):
        return Response(SavedAddressSerializer(SavedAddress.objects.filter(user=request.user), many=True).data)

    @extend_schema(tags=["addresses"], request=SavedAddressSerializer, responses={201: SavedAddressSerializer},
                   summary="Save an address (up to 10; one Home and one Work). The first one becomes the default.")
    def post(self, request):
        s = SavedAddressSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        address = services.add(request.user, **s.validated_data)
        return Response(SavedAddressSerializer(address).data, status=status.HTTP_201_CREATED)


class AddressDetailView(APIView):
    permission_classes = [IsCustomer]

    def _get(self, request, pk):
        return get_object_or_404(SavedAddress, pk=pk, user=request.user)

    @extend_schema(tags=["addresses"], responses={200: SavedAddressSerializer})
    def get(self, request, pk):
        return Response(SavedAddressSerializer(self._get(request, pk)).data)

    @extend_schema(tags=["addresses"], request=SavedAddressSerializer, responses={200: SavedAddressSerializer},
                   summary="Change a saved address.")
    def patch(self, request, pk):
        address = self._get(request, pk)
        s = SavedAddressSerializer(address, data=request.data, partial=True)
        s.is_valid(raise_exception=True)
        return Response(SavedAddressSerializer(services.update(address, **s.validated_data)).data)

    @extend_schema(tags=["addresses"], responses={204: None},
                   summary="Delete a saved address. If it was the default, the oldest one left becomes the default.")
    def delete(self, request, pk):
        services.delete(self._get(request, pk))
        return Response(status=status.HTTP_204_NO_CONTENT)


class MakeDefaultView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(tags=["addresses"], request=None, responses={200: SavedAddressSerializer},
                   summary="Use this address first when posting a job.")
    def post(self, request, pk):
        address = get_object_or_404(SavedAddress, pk=pk, user=request.user)
        return Response(SavedAddressSerializer(services.make_default(address)).data)
