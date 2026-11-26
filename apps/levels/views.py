from drf_spectacular.utils import extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsWorker

from . import services
from .serializers import LevelProgressSerializer


class MyLevelView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["workers"], responses={200: LevelProgressSerializer},
                   summary="Worker: my level, badges, and what the next level needs")
    def get(self, request):
        return Response(LevelProgressSerializer(services.progress(request.user.worker_profile)).data)
