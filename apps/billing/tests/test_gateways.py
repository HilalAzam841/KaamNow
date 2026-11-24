import base64
import hashlib
import hmac
from datetime import timedelta
from decimal import Decimal
from unittest import mock

import pytest
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from django.utils import timezone

from apps.billing.gateways.easypaisa import encrypt_request
from apps.billing.gateways.jazzcash import secure_hash
from apps.billing.models import Commission, LedgerEntry, Payment
from apps.billing.services import expire_stale_online_payments
from conftest import EASYPAISA_TEST_CONFIG, JAZZCASH_TEST_CONFIG, client_for, data, jazzcash_callback

pytestmark = pytest.mark.django_db
PAY = "/api/v1/payments/"
JC_CB = "/api/v1/payments/callbacks/jazzcash/"
EP_CB = "/api/v1/payments/callbacks/easypaisa/"


@pytest.fixture
def booking(customer, worker, completed_booking_factory):
    return completed_booking_factory(customer, worker, "2000")


def start(customer, booking, method):
    resp = client_for(customer).post(PAY, {"booking": booking.pk, "method": method})
    assert resp.status_code == 201, resp.json()
    return data(resp)


class TestJazzCashHash:
    def test_matches_documented_algorithm(self):
        fields = {"pp_Amount": "200000", "pp_TxnRefNo": "KN1", "pp_Version": "1.1", "pp_BankID": "",
                  "pp_SecureHash": "ignored", "other": "x"}
        # Independent re-implementation: sorted pp_* non-empty values, salt first, HMAC-SHA256 upper hex.
        message = "salt&200000&KN1&1.1"
        expected = hmac.new(b"salt", message.encode(), hashlib.sha256).hexdigest().upper()
        assert secure_hash(fields, "salt") == expected


class TestJazzCashFlow:
    def test_not_configured(self, customer, booking, settings):
        settings.PAYMENT_GATEWAYS = {"jazzcash": {}, "easypaisa": {}}
        resp = client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash"})
        assert resp.status_code == 400
        assert not Payment.objects.exists()

    def test_checkout_is_signed_and_amount_from_server(self, customer, booking, gateways):
        body = start(customer, booking, "jazzcash")
        assert body["status"] == "pending" and body["amount"] == "2000.00"
        checkout = body["checkout"]
        assert checkout["url"] == JAZZCASH_TEST_CONFIG["CHECKOUT_URL"] and checkout["method"] == "POST"
        fields = checkout["fields"]
        assert fields["pp_Amount"] == "200000"
        assert fields["pp_TxnRefNo"] == body["reference"]
        assert fields["pp_SecureHash"] == secure_hash(fields, JAZZCASH_TEST_CONFIG["INTEGRITY_SALT"])

    def test_successful_callback_settles_payment(self, api, customer, worker, booking, gateways):
        body = start(customer, booking, "jazzcash")
        payment = Payment.objects.get(pk=body["id"])
        resp = api.post(JC_CB, jazzcash_callback(payment), format="multipart")
        assert resp.status_code == 200
        payment.refresh_from_db()
        assert payment.status == "completed"
        assert payment.gateway_transaction_id == "123456789012"
        assert "pp_SecureHash" not in payment.gateway_response
        entries = {e.entry_type: e.amount for e in LedgerEntry.objects.filter(payment=payment)}
        assert entries == {"customer_payment": Decimal("2000.00"), "platform_commission": Decimal("200.00"),
                           "worker_earning": Decimal("1800.00")}
        # Platform holds the money, so the commission is collected.
        assert Commission.objects.get(booking=booking).status == "collected"

    def test_replayed_callback_is_idempotent(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        payload = jazzcash_callback(payment)
        api.post(JC_CB, payload, format="multipart")
        api.post(JC_CB, payload, format="multipart")
        assert LedgerEntry.objects.filter(payment=payment).count() == 3

    def test_tampered_amount_rejected(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        payload = jazzcash_callback(payment)
        payload["pp_Amount"] = "100"  # changed after signing
        assert api.post(JC_CB, payload, format="multipart").status_code == 400
        payment.refresh_from_db()
        assert payment.status == "pending"

    def test_forged_signature_rejected(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        payload = jazzcash_callback(payment, salt="attacker-guess")
        assert api.post(JC_CB, payload, format="multipart").status_code == 400
        payload.pop("pp_SecureHash")
        assert api.post(JC_CB, payload, format="multipart").status_code == 400
        payment.refresh_from_db()
        assert payment.status == "pending"

    def test_signed_but_wrong_amount_is_disputed(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        api.post(JC_CB, jazzcash_callback(payment, amount=Decimal("10")), format="multipart")
        payment.refresh_from_db()
        assert payment.status == "disputed"
        assert not LedgerEntry.objects.filter(payment=payment).exists()

    def test_failed_transaction(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        api.post(JC_CB, jazzcash_callback(payment, code="124"), format="multipart")
        payment.refresh_from_db()
        assert payment.status == "failed"
        # Customer can retry after a failure.
        assert client_for(customer).post(PAY, {"booking": booking.pk, "method": "jazzcash"}).status_code == 201

    def test_unknown_reference(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        payload = jazzcash_callback(payment)
        payload["pp_TxnRefNo"] = "KNUNKNOWN"
        payload["pp_SecureHash"] = secure_hash(payload, JAZZCASH_TEST_CONFIG["INTEGRITY_SALT"])
        assert api.post(JC_CB, payload, format="multipart").status_code == 400

    def test_jazzcash_callback_cannot_settle_easypaisa_payment(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "easypaisa")["id"])
        assert api.post(JC_CB, jazzcash_callback(payment), format="multipart").status_code == 400
        payment.refresh_from_db()
        assert payment.status == "pending"

    def test_late_success_after_expiry_is_disputed(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        Payment.objects.filter(pk=payment.pk).update(expires_at=timezone.now() - timedelta(minutes=1))
        assert expire_stale_online_payments() == 1
        api.post(JC_CB, jazzcash_callback(payment), format="multipart")
        payment.refresh_from_db()
        assert payment.status == "disputed"

    def test_browser_redirect_gets_html(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        resp = api.post(JC_CB, jazzcash_callback(payment), format="multipart", HTTP_ACCEPT="text/html")
        assert resp.status_code == 200
        assert b"kaamnow-payment" in resp.content and b'data-status=\'completed\'' in resp.content

    def test_duplicate_pending_and_switch_to_cash(self, customer, booking, gateways):
        c = client_for(customer)
        first = start(customer, booking, "jazzcash")
        assert c.post(PAY, {"booking": booking.pk, "method": "jazzcash"}).status_code == 409
        # Switching to cash closes the abandoned online attempt.
        assert c.post(PAY, {"booking": booking.pk, "method": "cash"}).status_code == 201
        assert Payment.objects.get(pk=first["id"]).status == "failed"

    def test_paid_booking_cannot_be_paid_again(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "jazzcash")["id"])
        api.post(JC_CB, jazzcash_callback(payment), format="multipart")
        assert client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}).status_code == 409

    def test_worker_cannot_confirm_online_payment(self, customer, worker, booking, gateways):
        payment_id = start(customer, booking, "jazzcash")["id"]
        assert client_for(worker.user).post(f"{PAY}{payment_id}/confirm/").status_code == 400


def _decrypt(token, key):
    decryptor = Cipher(algorithms.AES(key.encode()), modes.ECB()).decryptor()
    padded = decryptor.update(base64.b64decode(token)) + decryptor.finalize()
    unpadder = padding.PKCS7(128).unpadder()
    return (unpadder.update(padded) + unpadder.finalize()).decode()


class TestEasypaisa:
    def test_checkout_hash_decrypts_to_sorted_request(self, customer, booking, gateways):
        body = start(customer, booking, "easypaisa")
        fields = body["checkout"]["fields"]
        plain = _decrypt(fields["merchantHashedReq"], EASYPAISA_TEST_CONFIG["HASH_KEY"])
        assert plain.startswith("amount=2000.0&expiryDate=")
        assert f"orderRefNum={body['reference']}" in plain and plain.endswith("storeId=12345")

    def test_encrypt_rejects_bad_key(self):
        from apps.billing.gateways import GatewayError

        with pytest.raises(GatewayError):
            encrypt_request({"a": "1"}, "short")

    def _inquiry(self, payment, status="PAID", amount=None, code="0000"):
        return {"responseCode": code, "orderId": payment.reference, "transactionStatus": status,
                "transactionAmount": str(amount if amount is not None else payment.amount), "transactionId": "EP99"}

    def test_paid_inquiry_settles(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "easypaisa")["id"])
        with mock.patch("apps.billing.gateways.easypaisa.EasypaisaGateway.inquire",
                        return_value=self._inquiry(payment)) as inquire:
            resp = api.get(EP_CB, {"orderRefNumber": payment.reference, "status": "Success"})
        assert resp.status_code == 200
        inquire.assert_called_once_with(payment.reference)
        payment.refresh_from_db()
        assert payment.status == "completed" and payment.gateway_transaction_id == "EP99"

    def test_client_claimed_success_is_not_trusted(self, api, customer, booking, gateways):
        """The redirect says success, but the server-side inquiry says not paid."""
        payment = Payment.objects.get(pk=start(customer, booking, "easypaisa")["id"])
        with mock.patch("apps.billing.gateways.easypaisa.EasypaisaGateway.inquire",
                        return_value=self._inquiry(payment, status="FAILED")):
            api.get(EP_CB, {"orderRefNumber": payment.reference, "status": "Success"})
        payment.refresh_from_db()
        assert payment.status == "failed"

    def test_inquiry_error_leaves_payment_pending(self, api, customer, booking, gateways):
        import requests

        payment = Payment.objects.get(pk=start(customer, booking, "easypaisa")["id"])
        with mock.patch("apps.billing.gateways.easypaisa.requests.post", side_effect=requests.ConnectionError):
            resp = api.get(EP_CB, {"orderRefNumber": payment.reference})
        assert resp.status_code == 400
        payment.refresh_from_db()
        assert payment.status == "pending"

    def test_inquiry_request_shape(self, customer, booking, gateways):
        from apps.billing.gateways import get_gateway

        payment = Payment.objects.get(pk=start(customer, booking, "easypaisa")["id"])
        response = mock.Mock(status_code=200, json=lambda: self._inquiry(payment))
        response.raise_for_status = lambda: None
        with mock.patch("apps.billing.gateways.easypaisa.requests.post", return_value=response) as post:
            get_gateway("easypaisa").inquire(payment.reference)
        kwargs = post.call_args.kwargs
        assert kwargs["json"] == {"orderId": payment.reference, "storeId": "12345", "accountNum": "654321"}
        assert base64.b64decode(kwargs["headers"]["Credentials"]).decode() == "kaamnow:secret"

    def test_amount_mismatch_disputed(self, api, customer, booking, gateways):
        payment = Payment.objects.get(pk=start(customer, booking, "easypaisa")["id"])
        with mock.patch("apps.billing.gateways.easypaisa.EasypaisaGateway.inquire",
                        return_value=self._inquiry(payment, amount="1.00")):
            api.get(EP_CB, {"orderRefNumber": payment.reference})
        payment.refresh_from_db()
        assert payment.status == "disputed"

    def test_missing_reference(self, api, gateways):
        assert api.get(EP_CB).status_code == 400
