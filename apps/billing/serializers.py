from decimal import Decimal

from django.utils.translation import gettext as _
from rest_framework import serializers

from apps.catalog.models import ServiceCategory
from apps.jobs.models import Booking
from apps.support.models import Complaint

from .models import (
    Commission,
    FeaturedListing,
    FeaturedPlan,
    LedgerEntry,
    Payment,
    PlatformSettings,
    Refund,
    SubscriptionPlan,
    WorkerSettlement,
    WorkerSubscription,
)

ONLINE_METHOD_CHOICES = [(Payment.Method.JAZZCASH.value, "JazzCash"), (Payment.Method.EASYPAISA.value, "Easypaisa")]


class PaymentCreateSerializer(serializers.Serializer):
    booking = serializers.PrimaryKeyRelatedField(queryset=Booking.objects.all())
    method = serializers.ChoiceField(choices=Payment.Method.choices, default=Payment.Method.CASH)
    promo_code = serializers.CharField(max_length=30, required=False, allow_blank=True, default="")
    use_credit = serializers.BooleanField(default=False, help_text="Take the customer's credit off the total.")


class CheckoutSerializer(serializers.Serializer):
    url = serializers.URLField()
    method = serializers.CharField()
    fields = serializers.DictField(child=serializers.CharField())


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = [
            "id", "purpose", "booking", "amount", "method", "status", "reference", "failure_reason", "expires_at",
            "confirmed_at", "refunded_amount", "discount_amount", "created_at", "updated_at",
        ]
        read_only_fields = fields


class ReceiptLineSerializer(serializers.Serializer):
    label = serializers.CharField()
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)


class ReceiptRefundSerializer(serializers.Serializer):
    date = serializers.DateField()
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    reference = serializers.CharField()


class ReceiptSerializer(serializers.Serializer):
    number = serializers.CharField()
    issued_at = serializers.DateTimeField()
    status = serializers.CharField()
    purpose = serializers.CharField()
    booking = serializers.IntegerField(allow_null=True)
    title = serializers.CharField()
    service = serializers.CharField()
    billed_to = serializers.CharField()
    worker = serializers.CharField()
    method = serializers.CharField()
    method_label = serializers.CharField()
    transaction_id = serializers.CharField()
    lines = ReceiptLineSerializer(many=True)
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    refunds = ReceiptRefundSerializer(many=True)
    refunded = serializers.DecimalField(max_digits=12, decimal_places=2)
    net_paid = serializers.DecimalField(max_digits=12, decimal_places=2)
    company = serializers.CharField()
    company_address = serializers.CharField()
    tax_number = serializers.CharField()


class PaymentWithCheckoutSerializer(PaymentSerializer):
    checkout = CheckoutSerializer(
        read_only=True, allow_null=True,
        help_text="For JazzCash/Easypaisa: POST these fields to `url` (e.g. in a WebView). Null for cash.",
    )

    class Meta(PaymentSerializer.Meta):
        fields = PaymentSerializer.Meta.fields + ["checkout"]
        read_only_fields = fields


class CommissionSerializer(serializers.ModelSerializer):
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)

    class Meta:
        model = Commission
        fields = [
            "id", "booking", "worker", "worker_name", "gross_amount", "rate_percent", "commission_amount",
            "worker_earning", "status", "created_at",
        ]
        read_only_fields = fields


class LedgerEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = LedgerEntry
        fields = ["id", "payment", "booking", "worker", "entry_type", "amount", "description", "created_at"]
        read_only_fields = fields


class PlatformSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlatformSettings
        fields = ["commission_percent", "emergency_fee", "emergency_enabled", "min_payout", "commission_debt_limit",
                  "referral_reward", "referral_welcome_credit", "referral_min_booking", "max_discount_percent",
                  "reminder_sms_enabled", "no_show_grace_minutes", "cancellation_fee_enabled",
                  "cancellation_free_minutes", "cancellation_window_minutes", "late_cancellation_fee",
                  "on_the_way_cancellation_fee", "updated_at"]
        read_only_fields = ["updated_at"]


class EarningsSummarySerializer(serializers.Serializer):
    completed_jobs = serializers.IntegerField()
    gross_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    net_earnings = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_pending = serializers.DecimalField(max_digits=14, decimal_places=2)
    current_commission_percent = serializers.DecimalField(max_digits=5, decimal_places=2)
    recent = CommissionSerializer(many=True)


# --- Earnings reports ------------------------------------------------------------
def _money():
    return serializers.DecimalField(max_digits=14, decimal_places=2)


class ReportTotalsSerializer(serializers.Serializer):
    jobs = serializers.IntegerField()
    gross = _money()
    commission = _money()
    discount = _money()
    earnings = _money()
    adjustments = _money()
    net = _money()


class PreviousTotalsSerializer(ReportTotalsSerializer):
    start = serializers.DateField()
    end = serializers.DateField()


class ReportBucketSerializer(serializers.Serializer):
    start = serializers.DateField()
    jobs = serializers.IntegerField()
    gross = _money()
    net = _money()


class ReportServiceSerializer(serializers.Serializer):
    category = serializers.IntegerField()
    name = serializers.CharField()
    jobs = serializers.IntegerField()
    gross = _money()
    net = _money()


class ReportPaymentSplitSerializer(serializers.Serializer):
    jobs = serializers.IntegerField()
    gross = _money()
    net = _money()


class ReportByPaymentSerializer(serializers.Serializer):
    cash = ReportPaymentSplitSerializer()
    online = ReportPaymentSplitSerializer()
    unpaid = ReportPaymentSplitSerializer()


class EarningsReportSerializer(serializers.Serializer):
    start = serializers.DateField()
    end = serializers.DateField()
    group = serializers.ChoiceField(choices=[("day", "Day"), ("week", "Week"), ("month", "Month")])
    totals = ReportTotalsSerializer()
    average_per_job = _money()
    previous = PreviousTotalsSerializer()
    series = ReportBucketSerializer(many=True)
    by_service = ReportServiceSerializer(many=True)
    by_payment = ReportByPaymentSerializer()


# --- Subscriptions -------------------------------------------------------------
class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = [
            "id", "name", "slug", "description", "price", "duration_days", "commission_percent",
            "daily_offer_limit", "benefits", "badge", "is_default", "is_active", "sort_order",
        ]
        read_only_fields = ["id"]

    def validate_benefits(self, value):
        if not isinstance(value, list) or not all(isinstance(b, str) and len(b) <= 120 for b in value):
            raise serializers.ValidationError(_("Benefits must be a list of short strings."))
        return value

    def validate(self, attrs):
        is_default = attrs.get("is_default", getattr(self.instance, "is_default", False))
        price = attrs.get("price", getattr(self.instance, "price", None))
        if is_default and price not in (None, 0) and price != 0:
            raise serializers.ValidationError({"is_default": "Only a free plan can be the default plan."})
        return attrs


class SubscribeSerializer(serializers.Serializer):
    plan = serializers.PrimaryKeyRelatedField(queryset=SubscriptionPlan.objects.filter(is_active=True))
    method = serializers.ChoiceField(choices=ONLINE_METHOD_CHOICES, required=False)


class WorkerSubscriptionSerializer(serializers.ModelSerializer):
    plan = SubscriptionPlanSerializer(read_only=True)
    payment = PaymentSerializer(read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)

    class Meta:
        model = WorkerSubscription
        fields = ["id", "worker", "worker_name", "plan", "status", "amount", "starts_at", "ends_at", "payment",
                  "created_at"]
        read_only_fields = fields


class SubscribeResponseSerializer(serializers.Serializer):
    subscription = WorkerSubscriptionSerializer()
    checkout = CheckoutSerializer(allow_null=True)


class MySubscriptionSerializer(serializers.Serializer):
    plan = SubscriptionPlanSerializer()
    subscription = WorkerSubscriptionSerializer(allow_null=True)
    offers_today = serializers.IntegerField()
    offers_remaining_today = serializers.IntegerField(allow_null=True)
    commission_percent = serializers.DecimalField(max_digits=5, decimal_places=2)


# --- Featured listings ----------------------------------------------------------
class FeaturedPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeaturedPlan
        fields = ["id", "name", "duration_days", "price", "is_active"]
        read_only_fields = ["id"]


class FeaturedPurchaseSerializer(serializers.Serializer):
    plan = serializers.PrimaryKeyRelatedField(queryset=FeaturedPlan.objects.filter(is_active=True))
    category = serializers.PrimaryKeyRelatedField(queryset=ServiceCategory.objects.filter(is_active=True))
    method = serializers.ChoiceField(choices=ONLINE_METHOD_CHOICES)


class FeaturedListingSerializer(serializers.ModelSerializer):
    plan = FeaturedPlanSerializer(read_only=True)
    category_name = serializers.CharField(source="category.display_name", read_only=True)
    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    payment = PaymentSerializer(read_only=True)

    class Meta:
        model = FeaturedListing
        fields = ["id", "worker", "worker_name", "category", "category_name", "plan", "status", "amount",
                  "starts_at", "ends_at", "payment", "created_at"]
        read_only_fields = fields


class FeaturedPurchaseResponseSerializer(serializers.Serializer):
    listing = FeaturedListingSerializer()
    checkout = CheckoutSerializer()


# --- Worker wallet: payouts and commission settlement -------------------------
PAYOUT_METHOD_CHOICES = [
    (WorkerSettlement.Method.JAZZCASH.value, "JazzCash"),
    (WorkerSettlement.Method.EASYPAISA.value, "Easypaisa"),
    (WorkerSettlement.Method.BANK.value, "Bank transfer"),
]


class SettlementSerializer(serializers.ModelSerializer):
    """Shown only to the worker it belongs to and to admins (it holds their account number)."""

    worker_name = serializers.CharField(source="worker.user.full_name", read_only=True)
    worker_phone = serializers.CharField(source="worker.user.phone", read_only=True)
    bookings = serializers.SerializerMethodField()

    class Meta:
        model = WorkerSettlement
        fields = [
            "id", "worker", "worker_name", "worker_phone", "kind", "status", "amount", "earnings_amount",
            "commission_amount", "method", "account_title", "account_number", "reference", "note", "payment",
            "bookings", "processed_at", "created_at",
        ]
        read_only_fields = fields

    def get_bookings(self, obj) -> list[int]:
        return [c.booking_id for c in obj.commissions.all()]


class PayoutAccountSerializer(serializers.Serializer):
    method = serializers.ChoiceField(choices=PAYOUT_METHOD_CHOICES)
    account_title = serializers.CharField(max_length=100)
    account_number = serializers.CharField(max_length=34)


class PayoutRequestSerializer(PayoutAccountSerializer):
    def validate(self, attrs):
        number = "".join(attrs["account_number"].split()).upper()
        if attrs["method"] == WorkerSettlement.Method.BANK:
            # Pakistani IBAN: PK, 2 check digits, 4-letter bank code, 16 digits.
            import re

            if not re.fullmatch(r"PK\d{2}[A-Z]{4}\d{16}", number):
                raise serializers.ValidationError({"account_number": _("Enter your IBAN, e.g. PK36SCBL0000001123456702.")})
        else:
            digits = number.replace("-", "")
            if digits.startswith("+92"):
                digits = "0" + digits[3:]
            elif digits.startswith("92"):
                digits = "0" + digits[2:]
            if not (digits.isdigit() and len(digits) == 11 and digits.startswith("03")):
                raise serializers.ValidationError({"account_number": _("Enter the mobile number of the account, e.g. 03001234567.")})
            number = digits
        attrs["account_number"] = number
        return attrs


class LastPayoutAccountSerializer(PayoutAccountSerializer):
    pass


class WalletSerializer(serializers.Serializer):
    earnings_held = serializers.DecimalField(max_digits=14, decimal_places=2,
                                             help_text="Your share of online payments, held by KaamNow.")
    commission_owed = serializers.DecimalField(max_digits=14, decimal_places=2,
                                               help_text="Commission on jobs paid to you in cash.")
    balance = serializers.DecimalField(max_digits=14, decimal_places=2,
                                       help_text="Positive: KaamNow owes you. Negative: you owe KaamNow.")
    min_payout = serializers.DecimalField(max_digits=10, decimal_places=2)
    commission_debt_limit = serializers.DecimalField(max_digits=10, decimal_places=2)
    can_request_payout = serializers.BooleanField()
    must_pay_commission = serializers.BooleanField()
    offers_blocked = serializers.BooleanField()
    open_settlement = SettlementSerializer(allow_null=True)
    last_payout_account = LastPayoutAccountSerializer(allow_null=True)
    settlements = SettlementSerializer(many=True)


class CommissionPaymentSerializer(serializers.Serializer):
    method = serializers.ChoiceField(choices=ONLINE_METHOD_CHOICES)


class CommissionPaymentResponseSerializer(serializers.Serializer):
    settlement = SettlementSerializer()
    payment = PaymentWithCheckoutSerializer()


class MarkPayoutPaidSerializer(serializers.Serializer):
    reference = serializers.CharField(max_length=100, help_text="The transfer's transaction ID.")


class RejectPayoutSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)


RECEIVED_METHOD_CHOICES = [(WorkerSettlement.Method.CASH.value, "Cash"),
                           (WorkerSettlement.Method.BANK.value, "Bank transfer")]


class RecordCommissionSerializer(serializers.Serializer):
    method = serializers.ChoiceField(choices=RECEIVED_METHOD_CHOICES)
    reference = serializers.CharField(max_length=100, help_text="Receipt number or transfer ID.")


class WorkerBalanceSerializer(serializers.Serializer):
    worker = serializers.IntegerField()
    worker_name = serializers.CharField()
    worker_phone = serializers.CharField()
    earnings_held = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_owed = serializers.DecimalField(max_digits=14, decimal_places=2)
    balance = serializers.DecimalField(max_digits=14, decimal_places=2)


class RefundSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source="created_by.full_name", read_only=True)

    class Meta:
        model = Refund
        fields = ["id", "payment", "amount", "worker_share", "method", "reason", "reference", "complaint",
                  "created_by_name", "created_at"]
        read_only_fields = fields


class AdminPaymentSerializer(PaymentSerializer):
    payer_name = serializers.CharField(source="payer.full_name", read_only=True)
    payer_phone = serializers.CharField(source="payer.phone", read_only=True)
    worker_name = serializers.CharField(source="booking.worker.user.full_name", read_only=True, default=None)
    refundable_amount = serializers.SerializerMethodField()
    refunds = RefundSerializer(many=True, read_only=True)

    class Meta(PaymentSerializer.Meta):
        fields = PaymentSerializer.Meta.fields + [
            "payer", "payer_name", "payer_phone", "worker_name", "gateway_transaction_id", "refundable_amount",
            "refunds",
        ]
        read_only_fields = fields

    def get_refundable_amount(self, obj) -> str:
        from .refunds import refundable

        return f"{refundable(obj):.2f}"


class RefundRequestSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("1.00"))
    method = serializers.ChoiceField(choices=Refund.Method.choices)
    reason = serializers.CharField(max_length=255)
    reference = serializers.CharField(max_length=100, help_text="Refund transaction ID or receipt number.")
    charge_worker = serializers.BooleanField(
        default=False, help_text="Take the worker's share of the refund (their earning's part) from their wallet."
    )
    complaint = serializers.PrimaryKeyRelatedField(queryset=Complaint.objects.all(), required=False, allow_null=True)


class ResolvePaymentSerializer(serializers.Serializer):
    resolution = serializers.ChoiceField(
        choices=[("accept", "Accept"), ("refund", "Refund"), ("reject", "Reject")],
        help_text="accept: the money counts as the booking's payment. refund: you sent it back. "
                  "reject: no money arrived.",
    )
    note = serializers.CharField(max_length=255)
    method = serializers.ChoiceField(choices=Refund.Method.choices, required=False)
    reference = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    complaint = serializers.PrimaryKeyRelatedField(queryset=Complaint.objects.all(), required=False, allow_null=True)

    def validate(self, attrs):
        if attrs["resolution"] == "refund" and (not attrs.get("method") or not attrs.get("reference", "").strip()):
            raise serializers.ValidationError({"reference": _("Give the refund method and its reference.")})
        return attrs
