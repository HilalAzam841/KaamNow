"""Payment gateway adapter interface.

Security rules every adapter follows:
  * The client app never reports success. Success is decided only from data
    the server verifies itself: a valid signature computed with a merchant
    secret, and/or a server-to-server status inquiry to the gateway.
  * The amount and reference in the verified data must match the Payment row.
"""

from dataclasses import dataclass, field
from decimal import Decimal


class GatewayError(Exception):
    """Gateway misconfigured or unreachable."""


class SignatureError(GatewayError):
    """Callback signature missing or invalid."""


@dataclass
class Checkout:
    """What the app needs to open the gateway's hosted page (e.g. in a WebView)."""

    url: str
    method: str
    fields: dict

    def as_dict(self):
        return {"url": self.url, "method": self.method, "fields": self.fields}


@dataclass
class GatewayResult:
    reference: str
    success: bool
    amount: Decimal | None
    transaction_id: str = ""
    message: str = ""
    raw: dict = field(default_factory=dict)


class PaymentGateway:
    method = ""
    required_settings: tuple = ()

    def __init__(self, config: dict):
        self.config = config

    @property
    def is_configured(self):
        return all(self.config.get(key) for key in self.required_settings)

    def ensure_configured(self):
        if not self.is_configured:
            raise GatewayError(f"{self.method} is not configured on this server.")

    def build_checkout(self, payment) -> Checkout:  # pragma: no cover - interface
        raise NotImplementedError

    def verify_callback(self, data: dict) -> GatewayResult:  # pragma: no cover - interface
        raise NotImplementedError
