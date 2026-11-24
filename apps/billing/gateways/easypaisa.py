"""Easypaisa Easypay hosted checkout.

Checkout: the request string "amount=..&expiryDate=..&orderRefNum=..&
paymentMethod=..&postBackURL=..&storeId=.." (keys sorted) is encrypted with
AES-128/ECB/PKCS5 using the merchant Hash Key and sent base64-encoded as
`merchantHashedReq`.

Confirmation: Easypay redirects the customer to our postback URL with the
order reference, but that redirect is not signed in a way we rely on.
Instead, the server always calls Easypaisa's Inquire Transaction API
(server-to-server, authenticated with the merchant credentials) and trusts
only that answer: transactionStatus must be PAID and the amount must match.

NOTE: Verify against the Easypaisa staging environment with your merchant
credentials before going live.
"""

import base64
from decimal import Decimal

import requests
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from django.utils import timezone

from .base import Checkout, GatewayError, GatewayResult, PaymentGateway

PAID_STATUSES = {"PAID"}


def encrypt_request(params: dict, hash_key: str) -> str:
    message = "&".join(f"{k}={params[k]}" for k in sorted(params))
    key = hash_key.encode()
    if len(key) not in (16, 24, 32):
        raise GatewayError("Easypaisa hash key must be 16, 24 or 32 bytes.")
    padder = padding.PKCS7(128).padder()
    padded = padder.update(message.encode()) + padder.finalize()
    encryptor = Cipher(algorithms.AES(key), modes.ECB()).encryptor()  # noqa: S305 - mandated by Easypay
    return base64.b64encode(encryptor.update(padded) + encryptor.finalize()).decode()


class EasypaisaGateway(PaymentGateway):
    method = "easypaisa"
    required_settings = ("STORE_ID", "HASH_KEY", "USERNAME", "PASSWORD", "ACCOUNT_NUM", "CHECKOUT_URL",
                         "INQUIRY_URL", "POSTBACK_URL")
    timeout = 15

    def build_checkout(self, payment) -> Checkout:
        self.ensure_configured()
        expires = timezone.localtime(payment.expires_at) if payment.expires_at else timezone.localtime()
        params = {
            "amount": f"{payment.amount:.1f}",
            "expiryDate": expires.strftime("%Y%m%d %H%M%S"),
            "orderRefNum": payment.reference,
            "paymentMethod": "MA_PAYMENT_METHOD",
            "postBackURL": self.config["POSTBACK_URL"],
            "storeId": self.config["STORE_ID"],
        }
        fields = {**params, "autoRedirect": "1",
                  "merchantHashedReq": encrypt_request(params, self.config["HASH_KEY"])}
        return Checkout(url=self.config["CHECKOUT_URL"], method="POST", fields=fields)

    def inquire(self, order_ref: str) -> dict:
        credentials = base64.b64encode(f"{self.config['USERNAME']}:{self.config['PASSWORD']}".encode()).decode()
        try:
            response = requests.post(
                self.config["INQUIRY_URL"],
                json={"orderId": order_ref, "storeId": self.config["STORE_ID"],
                      "accountNum": self.config["ACCOUNT_NUM"]},
                headers={"Credentials": credentials, "Content-Type": "application/json"},
                timeout=self.timeout,
            )
            response.raise_for_status()
            return response.json()
        except (requests.RequestException, ValueError) as exc:
            raise GatewayError(f"Easypaisa inquiry failed: {exc}") from exc

    def verify_callback(self, data: dict) -> GatewayResult:
        self.ensure_configured()
        data = {k: (v[0] if isinstance(v, list) and v else v) for k, v in dict(data).items()}
        order_ref = str(data.get("orderRefNumber") or data.get("orderRefNum") or "")
        if not order_ref:
            raise GatewayError("Missing order reference.")
        info = self.inquire(order_ref)
        if str(info.get("orderId", order_ref)) != order_ref:
            raise GatewayError("Inquiry returned a different order.")
        try:
            amount = Decimal(str(info.get("transactionAmount"))).quantize(Decimal("0.01"))
        except Exception:  # noqa: BLE001
            amount = None
        status = str(info.get("transactionStatus", "")).upper()
        return GatewayResult(
            reference=order_ref,
            success=str(info.get("responseCode")) == "0000" and status in PAID_STATUSES,
            amount=amount,
            transaction_id=str(info.get("transactionId", "")),
            message=f"{info.get('responseCode')}: {status}",
            raw=info,
        )
