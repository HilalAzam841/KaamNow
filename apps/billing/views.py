import logging
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import generics, mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsCustomer, IsPlatformAdmin, IsWorker

from . import services, wallet
from .gateways import GatewayError, SignatureError
from .models import (
    Commission,
    FeaturedListing,
    FeaturedPlan,
    Payment,
    SubscriptionPlan,
    WorkerSettlement,
    WorkerSubscription,
)
from .serializers import (
    CommissionPaymentResponseSerializer,
    CommissionPaymentSerializer,
    EarningsSummarySerializer,
    FeaturedListingSerializer,
    FeaturedPlanSerializer,
    FeaturedPurchaseResponseSerializer,
    FeaturedPurchaseSerializer,
    MySubscriptionSerializer,
    PaymentCreateSerializer,
    PaymentSerializer,
    PaymentWithCheckoutSerializer,
    PayoutRequestSerializer,
    SettlementSerializer,
    SubscribeResponseSerializer,
    SubscribeSerializer,
    SubscriptionPlanSerializer,
    WalletSerializer,
    WorkerSubscriptionSerializer,
)

logger = logging.getLogger(__name__)


@extend_schema_view(list=extend_schema(tags=["payments"]), retrieve=extend_schema(tags=["payments"]))
class PaymentViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = PaymentSerializer
    filterset_fields = ["status", "method", "booking", "purpose"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Payment.objects.none()
        user = self.request.user
        qs = Payment.objects.select_related("booking")
        if IsPlatformAdmin().has_permission(self.request, self):
            return qs
        return qs.filter(Q(payer=user) | Q(booking__worker__user=user))

    @extend_schema(
        tags=["payments"], request=PaymentCreateSerializer, responses={201: PaymentWithCheckoutSerializer},
        summary="Customer pays for a completed booking. Cash: worker confirms receipt. JazzCash/Easypaisa: "
        "open `checkout` in a WebView; the server confirms only after verifying the gateway callback. "
        "Optional `promo_code` and `use_credit` lower the amount (check first with `POST promos/check/`).",
    )
    def create(self, request):
        if not IsCustomer().has_permission(request, self):
            return Response({"detail": IsCustomer.message}, status=status.HTTP_403_FORBIDDEN)
        serializer = PaymentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        v = serializer.validated_data
        payment, checkout = services.record_payment(
            v["booking"], request.user, v["method"], promo_code=v["promo_code"], use_credit=v["use_credit"]
        )
        payment.checkout = checkout
        return Response(PaymentWithCheckoutSerializer(payment).data, status=status.HTTP_201_CREATED)

    @extend_schema(tags=["payments"], request=None, responses={200: PaymentSerializer},
                   summary="Worker confirms they received the cash.")
    @action(detail=True, methods=["post"])
    def confirm(self, request, pk=None):
        payment = self.get_object()
        payment = services.confirm_cash_payment(payment, request.user)
        return Response(PaymentSerializer(payment).data)


class GatewayCallbackView(APIView):
    """
    Server-side endpoint the payment gateway calls (or redirects the customer's
    browser to). The payload is verified with the merchant secret / a
    server-to-server inquiry before anything is settled. No authentication:
    trust comes from the verification, not from the caller.
    """

    authentication_classes = []
    permission_classes = [permissions.AllowAny]
    parser_classes = [FormParser, MultiPartParser, JSONParser]
    throttle_scope = "payment_callback"
    gateway = ""

    def perform_content_negotiation(self, request, force=False):
        # Gateways and browsers send all sorts of Accept headers; always answer.
        return super().perform_content_negotiation(request, force=True)

    def _handle(self, data):
        try:
            payment = services.handle_gateway_callback(self.gateway, data)
        except SignatureError:
            logger.warning("Rejected %s callback with invalid signature", self.gateway)
            return Response({"detail": "Invalid signature."}, status=status.HTTP_400_BAD_REQUEST)
        except GatewayError as exc:
            logger.warning("Rejected %s callback: %s", self.gateway, exc)
            return Response({"detail": "Callback could not be verified."}, status=status.HTTP_400_BAD_REQUEST)
        if "text/html" not in self.request.META.get("HTTP_ACCEPT", ""):
            return Response({"reference": payment.reference, "status": payment.status})
        # Browser redirect from the hosted page: show a minimal page the app's WebView can detect.
        html = (
            f"<!doctype html><title>KaamNow payment</title>"
            f"<p id='kaamnow-payment' data-reference='{payment.reference}' data-status='{payment.status}'>"
            f"Payment {payment.get_status_display().lower()}. You can return to the app.</p>"
        )
        return HttpResponse(html, content_type="text/html")

    @extend_schema(tags=["payments"], request=None, responses={200: OpenApiResponse(description="Settled status")})
    def post(self, request):
        return self._handle(request.data)

    @extend_schema(tags=["payments"], responses={200: OpenApiResponse(description="Settled status")})
    def get(self, request):
        return self._handle(request.query_params)


class JazzCashCallbackView(GatewayCallbackView):
    gateway = "jazzcash"


class EasypaisaCallbackView(GatewayCallbackView):
    gateway = "easypaisa"


class WorkerEarningsView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["payments"], responses={200: EarningsSummarySerializer},
                   summary="Worker: earnings and commission summary")
    def get(self, request):
        worker = request.user.worker_profile
        qs = Commission.objects.filter(worker=worker)
        agg = qs.aggregate(
            n=Count("id"), gross=Sum("gross_amount"), commission=Sum("commission_amount"),
            net=Sum("worker_earning"),
            pending=Sum("commission_amount", filter=Q(status=Commission.Status.PENDING)),
        )
        zero = Decimal("0.00")
        data = {
            "completed_jobs": agg["n"],
            "gross_amount": agg["gross"] or zero,
            "commission_amount": agg["commission"] or zero,
            "net_earnings": agg["net"] or zero,
            "commission_pending": agg["pending"] or zero,
            "current_commission_percent": services.effective_commission_rate(worker),
            "recent": qs.select_related("worker__user")[:20],
        }
        return Response(EarningsSummarySerializer(data).data)


# --------------------------------------------------------------------------
# Worker wallet
# --------------------------------------------------------------------------
class WalletView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["payments"], responses={200: WalletSerializer},
                   summary="Worker: balance with KaamNow (online earnings held minus cash commission owed)")
    def get(self, request):
        return Response(WalletSerializer(wallet.summary(request.user.worker_profile)).data)


class PayoutRequestView(APIView):
    permission_classes = [IsWorker]
    throttle_scope = "payout"

    @extend_schema(tags=["payments"], request=PayoutRequestSerializer, responses={201: SettlementSerializer},
                   summary="Worker: ask to be paid the whole balance. An admin sends it and marks it paid.")
    def post(self, request):
        serializer = PayoutRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        settlement = wallet.request_payout(request.user.worker_profile, **serializer.validated_data)
        return Response(SettlementSerializer(settlement).data, status=status.HTTP_201_CREATED)


class PayoutCancelView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["payments"], request=None, responses={200: SettlementSerializer},
                   summary="Worker: cancel an open payout request")
    def post(self, request, pk):
        settlement = get_object_or_404(WorkerSettlement, pk=pk, worker=request.user.worker_profile)
        return Response(SettlementSerializer(wallet.cancel_payout(settlement, request.user.worker_profile)).data)


class CommissionPaymentView(APIView):
    permission_classes = [IsWorker]
    throttle_scope = "payout"

    @extend_schema(tags=["payments"], request=CommissionPaymentSerializer,
                   responses={201: CommissionPaymentResponseSerializer},
                   summary="Worker: pay the commission owed with JazzCash or Easypaisa. Settled only after the "
                   "server verifies the gateway callback.")
    def post(self, request):
        serializer = CommissionPaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        settlement, payment, checkout = wallet.pay_commission(
            request.user.worker_profile, serializer.validated_data["method"]
        )
        payment.checkout = checkout
        return Response({"settlement": SettlementSerializer(settlement).data,
                         "payment": PaymentWithCheckoutSerializer(payment).data}, status=status.HTTP_201_CREATED)


# --------------------------------------------------------------------------
# Subscriptions
# --------------------------------------------------------------------------
@extend_schema(tags=["subscriptions"])
class SubscriptionPlanListView(generics.ListAPIView):
    serializer_class = SubscriptionPlanSerializer
    permission_classes = [permissions.AllowAny]
    pagination_class = None
    queryset = SubscriptionPlan.objects.filter(is_active=True)


class SubscribeView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(
        tags=["subscriptions"], request=SubscribeSerializer, responses={201: SubscribeResponseSerializer},
        summary="Worker subscribes. Free plans activate at once; paid plans return a gateway checkout and "
        "activate after the payment is verified.",
    )
    def post(self, request):
        serializer = SubscribeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subscription, checkout = services.subscribe(
            request.user.worker_profile, serializer.validated_data["plan"], serializer.validated_data.get("method")
        )
        return Response(
            {"subscription": WorkerSubscriptionSerializer(subscription).data, "checkout": checkout},
            status=status.HTTP_201_CREATED,
        )


class MySubscriptionView(APIView):
    permission_classes = [IsWorker]

    @extend_schema(tags=["subscriptions"], responses={200: MySubscriptionSerializer})
    def get(self, request):
        worker = request.user.worker_profile
        sub = services.active_subscription(worker)
        plan = services.current_plan(worker)
        used = services.offers_today(worker)
        limit = plan.daily_offer_limit if plan else None
        return Response({
            "plan": SubscriptionPlanSerializer(plan).data if plan else None,
            "subscription": WorkerSubscriptionSerializer(sub).data if sub else None,
            "offers_today": used,
            "offers_remaining_today": max(limit - used, 0) if limit is not None else None,
            "commission_percent": str(services.effective_commission_rate(worker)),
        })


@extend_schema(tags=["subscriptions"])
class SubscriptionHistoryView(generics.ListAPIView):
    permission_classes = [IsWorker]
    serializer_class = WorkerSubscriptionSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return WorkerSubscription.objects.none()
        return WorkerSubscription.objects.filter(worker__user=self.request.user).select_related("plan", "payment")


# --------------------------------------------------------------------------
# Featured listings
# --------------------------------------------------------------------------
@extend_schema(tags=["featured"])
class FeaturedPlanListView(generics.ListAPIView):
    serializer_class = FeaturedPlanSerializer
    permission_classes = [permissions.AllowAny]
    pagination_class = None
    queryset = FeaturedPlan.objects.filter(is_active=True)


class FeaturedPurchaseView(generics.ListAPIView):
    """GET: the worker's featured listings. POST: buy featured placement in a category."""

    permission_classes = [IsWorker]
    serializer_class = FeaturedListingSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return FeaturedListing.objects.none()
        return FeaturedListing.objects.filter(worker__user=self.request.user).select_related(
            "plan", "category", "payment", "worker__user"
        )

    @extend_schema(tags=["featured"])
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(tags=["featured"], request=FeaturedPurchaseSerializer,
                   responses={201: FeaturedPurchaseResponseSerializer})
    def post(self, request):
        serializer = FeaturedPurchaseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        listing, checkout = services.purchase_featured_listing(
            request.user.worker_profile, serializer.validated_data["plan"], serializer.validated_data["category"],
            serializer.validated_data["method"],
        )
        return Response({"listing": FeaturedListingSerializer(listing).data, "checkout": checkout},
                        status=status.HTTP_201_CREATED)
