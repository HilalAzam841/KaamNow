from django.conf import settings

from .base import Checkout, GatewayError, GatewayResult, PaymentGateway, SignatureError
from .easypaisa import EasypaisaGateway
from .jazzcash import JazzCashGateway

GATEWAYS = {"jazzcash": JazzCashGateway, "easypaisa": EasypaisaGateway}


def get_gateway(method) -> PaymentGateway:
    try:
        cls = GATEWAYS[method]
    except KeyError as exc:
        raise GatewayError(f"Unknown payment gateway '{method}'.") from exc
    return cls(settings.PAYMENT_GATEWAYS.get(method, {}))


__all__ = [
    "Checkout", "GatewayError", "GatewayResult", "PaymentGateway", "SignatureError", "get_gateway",
    "JazzCashGateway", "EasypaisaGateway",
]
