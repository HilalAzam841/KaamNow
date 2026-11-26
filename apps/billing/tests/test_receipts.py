"""Payment receipts: data for the app and PDF downloads in English and Urdu."""

from decimal import Decimal

import pytest

from apps.billing.models import Payment, WorkerSubscription
from conftest import client_for, data

from .test_subscriptions import buy

pytestmark = pytest.mark.django_db

PAY = "/api/v1/payments/"
ADMIN_PAYMENTS = "/api/v1/admin/payments/"


def payment_of(booking):
    return Payment.objects.get(booking=booking, status="completed")


class TestReceipt:
    def test_customer_receipt_for_a_cash_job(self, customer, worker, paid_cash):
        payment = payment_of(paid_cash("2000"))
        r = data(client_for(customer).get(f"{PAY}{payment.pk}/receipt/"))
        assert r["number"] == payment.reference
        assert r["booking"] == payment.booking_id
        assert (r["title"], r["service"]) == ("Fan repair", "Electrician")
        assert (r["billed_to"], r["worker"]) == (customer.full_name, worker.user.full_name)
        assert r["lines"] == [{"label": "Job price", "amount": "2000.00"}]
        assert (r["total"], r["net_paid"], r["refunded"]) == ("2000.00", "2000.00", "0.00")
        assert (r["method"], r["method_label"]) == ("cash", "Cash")
        assert r["company"] == "KaamNow" and r["tax_number"] == ""
        text = str(r)
        assert customer.phone not in text and worker.user.phone not in text
        assert "commission" not in text.lower() and "Gulberg" not in text

    def test_discount_and_emergency_fee_lines(self, customer, paid_cash):
        booking = paid_cash("2000")
        payment = payment_of(booking)
        type(booking).objects.filter(pk=booking.pk).update(emergency_fee=Decimal("300.00"))
        Payment.objects.filter(pk=payment.pk).update(discount_amount=Decimal("200.00"))
        r = data(client_for(customer).get(f"{PAY}{payment.pk}/receipt/"))
        assert r["lines"] == [
            {"label": "Job price", "amount": "2000.00"},
            {"label": "Emergency fee", "amount": "300.00"},
            {"label": "Discount", "amount": "-200.00"},
        ]

    def test_who_can_see_it(self, customer, worker, paid_cash, make_customer, make_worker, admin_user):
        payment = payment_of(paid_cash())
        url = f"{PAY}{payment.pk}/receipt/"
        assert client_for(worker.user).get(url).status_code == 200
        assert client_for(admin_user).get(url).status_code == 200
        assert client_for(make_customer()).get(url).status_code == 404
        assert client_for(make_worker(name="Kamran Ali").user).get(url).status_code == 404
        assert client_for(make_customer()).get(f"{url}pdf/").status_code == 404
        assert client_for(None).get(url).status_code == 401

    def test_no_receipt_before_the_payment_goes_through(self, customer, worker, completed_booking_factory):
        booking = completed_booking_factory(customer, worker)
        body = data(client_for(customer).post(PAY, {"booking": booking.pk, "method": "cash"}))
        assert client_for(customer).get(f"{PAY}{body['id']}/receipt/").status_code == 409
        assert client_for(customer).get(f"{PAY}{body['id']}/receipt/pdf/").status_code == 409

    def test_refunds_are_listed(self, customer, admin_user, paid_online):
        payment = payment_of(paid_online("2000"))
        assert client_for(admin_user).post(f"{ADMIN_PAYMENTS}{payment.pk}/refund/", {
            "amount": "500", "method": "gateway", "reason": "Part of the job not done", "reference": "JC-RF-1",
        }).status_code == 201
        r = data(client_for(customer).get(f"{PAY}{payment.pk}/receipt/"))
        assert (r["method_label"], r["transaction_id"] != "") == ("JazzCash", True)
        assert [(x["amount"], x["reference"]) for x in r["refunds"]] == [("500.00", "JC-RF-1")]
        assert (r["refunded"], r["net_paid"]) == ("500.00", "1500.00")
        pdf = client_for(customer).get(f"{PAY}{payment.pk}/receipt/pdf/?lang=en")
        assert pdf.status_code == 200 and pdf.content.startswith(b"%PDF")

    def test_worker_plan_receipt(self, worker, api, gateways):
        sub = buy(worker, "professional", api)
        r = data(client_for(worker.user).get(f"{PAY}{sub.payment_id}/receipt/"))
        assert r["purpose"] == "subscription" and r["booking"] is None
        assert r["title"] == f"{sub.plan.name} plan"
        assert r["lines"] == [{"label": f"{sub.plan.name} plan", "amount": str(sub.amount)}]
        assert WorkerSubscription.objects.count() == 1

    def test_receipt_labels_in_urdu(self, customer, paid_cash):
        payment = payment_of(paid_cash())
        r = data(client_for(customer).get(f"{PAY}{payment.pk}/receipt/", HTTP_ACCEPT_LANGUAGE="ur"))
        assert r["lines"][0]["label"] == "کام کی قیمت"
        assert r["method_label"] == "نقد"


class TestPdf:
    def test_english_pdf(self, customer, paid_cash, settings):
        settings.RECEIPT_TAX_NUMBER = "NTN 1234567-8"
        payment = payment_of(paid_cash())
        res = client_for(customer).get(f"{PAY}{payment.pk}/receipt/pdf/")
        assert res.status_code == 200
        assert res["Content-Type"] == "application/pdf"
        assert res["Content-Disposition"] == f'attachment; filename="kaamnow-receipt-{payment.reference}.pdf"'
        assert "no-store" in res["Cache-Control"]
        assert res.content.startswith(b"%PDF") and b"Helvetica" in res.content
        assert b"NotoNastaliq" not in res.content

    @pytest.mark.parametrize("how", ["header", "query", "saved"])
    def test_urdu_pdf(self, customer, paid_cash, how):
        payment = payment_of(paid_cash())
        url = f"{PAY}{payment.pk}/receipt/pdf/"
        client = client_for(customer)
        if how == "header":
            res = client.get(url, HTTP_ACCEPT_LANGUAGE="ur")
        elif how == "query":
            res = client.get(url, {"lang": "ur"}, HTTP_ACCEPT_LANGUAGE="en")
        else:
            customer.language = "ur"
            customer.save(update_fields=["language"])
            res = client.get(url)
        assert res.status_code == 200 and res.content.startswith(b"%PDF")
        assert b"NotoNastaliq" in res.content, "Urdu receipts embed the Urdu font"

    def test_query_overrides_urdu_header(self, customer, paid_cash):
        payment = payment_of(paid_cash())
        res = client_for(customer).get(f"{PAY}{payment.pk}/receipt/pdf/", {"lang": "en"}, HTTP_ACCEPT_LANGUAGE="ur")
        assert b"NotoNastaliq" not in res.content
