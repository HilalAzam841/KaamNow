"""JazzCash Hosted Checkout (Page Redirection, API version 1.1).

Request and callback integrity use JazzCash's documented `pp_SecureHash`:
  1. take every field whose name starts with "pp" (except pp_SecureHash) and
     whose value is not empty,
  2. sort them by field name (ASCII),
  3. join the values with "&" and prefix "<IntegritySalt>&",
  4. HMAC-SHA256 with the Integrity Salt as key, upper-case hex.

A response code of "000" means the transaction succeeded.

NOTE: Verify against the JazzCash sandbox with your merchant credentials
before going live. Field names follow the v1.1 merchant integration guide.
"""

import hashlib
import hmac
from datetime import timedelta
from decimal import Decimal

from django.utils import timezone

from .base import Checkout, GatewayResult, PaymentGateway, SignatureError

SUCCESS_CODES = {"000"}


def secure_hash(fields: dict, integrity_salt: str) -> str:
    items = sorted(
        (k, str(v)) for k, v in fields.items()
        if k.lower().startswith("pp") and k != "pp_SecureHash" and v not in (None, "")
    )
    message = "&".join([integrity_salt] + [v for _, v in items])
    return hmac.new(integrity_salt.encode(), message.encode(), hashlib.sha256).hexdigest().upper()


def to_paisa(amount: Decimal) -> str:
    return str(int((Decimal(amount) * 100).quantize(Decimal("1"))))


class JazzCashGateway(PaymentGateway):
    method = "jazzcash"
    required_settings = ("MERCHANT_ID", "PASSWORD", "INTEGRITY_SALT", "CHECKOUT_URL", "RETURN_URL")

    def build_checkout(self, payment) -> Checkout:
        self.ensure_configured()
        now = timezone.localtime()
        expires = timezone.localtime(payment.expires_at) if payment.expires_at else now + timedelta(minutes=30)
        fields = {
            "pp_Version": "1.1",
            "pp_TxnType": "",
            "pp_Language": "EN",
            "pp_MerchantID": self.config["MERCHANT_ID"],
            "pp_SubMerchantID": "",
            "pp_Password": self.config["PASSWORD"],
            "pp_BankID": "",
            "pp_ProductID": "",
            "pp_TxnRefNo": payment.reference,
            "pp_Amount": to_paisa(payment.amount),
            "pp_TxnCurrency": "PKR",
            "pp_TxnDateTime": now.strftime("%Y%m%d%H%M%S"),
            "pp_BillReference": f"kn{payment.pk}",
            "pp_Description": f"KaamNow {payment.get_purpose_display()}"[:100],
            "pp_TxnExpiryDateTime": expires.strftime("%Y%m%d%H%M%S"),
            "pp_ReturnURL": self.config["RETURN_URL"],
            "ppmpf_1": str(payment.pk),
        }
        fields["pp_SecureHash"] = secure_hash(fields, self.config["INTEGRITY_SALT"])
        return Checkout(url=self.config["CHECKOUT_URL"], method="POST", fields=fields)

    def verify_callback(self, data: dict) -> GatewayResult:
        self.ensure_configured()
        data = {k: (v[0] if isinstance(v, list) and v else v) for k, v in dict(data).items()}
        received = str(data.get("pp_SecureHash", ""))
        expected = secure_hash(data, self.config["INTEGRITY_SALT"])
        if not received or not hmac.compare_digest(received.upper(), expected):
            raise SignatureError("Invalid JazzCash secure hash.")
        if data.get("pp_MerchantID") and data["pp_MerchantID"] != self.config["MERCHANT_ID"]:
            raise SignatureError("Callback is for a different merchant.")
        try:
            amount = (Decimal(str(data.get("pp_Amount"))) / 100).quantize(Decimal("0.01"))
        except Exception:  # noqa: BLE001
            amount = None
        code = str(data.get("pp_ResponseCode", ""))
        safe_raw = {k: v for k, v in data.items() if k not in ("pp_Password", "pp_SecureHash")}
        return GatewayResult(
            reference=str(data.get("pp_TxnRefNo", "")),
            success=code in SUCCESS_CODES,
            amount=amount,
            transaction_id=str(data.get("pp_RetreivalReferenceNo") or data.get("pp_TxnRefNo", "")),
            message=f"{code}: {data.get('pp_ResponseMessage', '')}",
            raw=safe_raw,
        )
