"""Receipts for completed payments, as data (for the app) and as a PDF in English or Urdu.

A receipt shows what was paid and how: no phone numbers, addresses or commission. The payer, the
booking's worker and admins can see it (the same people who can see the payment).
"""

from decimal import Decimal
from pathlib import Path

from django.conf import settings
from django.utils import timezone, translation
from django.utils.translation import gettext as _

from apps.common.exceptions import ConflictError

from .models import Payment

ZERO = Decimal("0.00")
FONTS = Path(__file__).resolve().parent / "fonts"
RECEIPT_STATUSES = (Payment.Status.COMPLETED, Payment.Status.REFUNDED)


def money(value):
    value = Decimal(value)
    text = _("Rs {amount}").format(amount=f"{abs(value):,.0f}")
    return f"-{text}" if value < 0 else text


def method_label(method):
    return {"cash": _("Cash"), "jazzcash": "JazzCash", "easypaisa": "Easypaisa"}.get(method, method)


def _category_name(category):
    urdu = (translation.get_language() or "").startswith("ur")
    return (category.name_ur if urdu else "") or category.name


def check_ready(payment):
    if payment.status not in RECEIPT_STATUSES:
        raise ConflictError(_("A receipt is ready once the payment has gone through."))


def receipt_data(payment):
    """Everything on the receipt, in the active language."""
    check_ready(payment)
    lines = []
    title = ""
    service = ""
    worker = ""
    booking_id = None
    if payment.purpose == Payment.Purpose.BOOKING:
        booking = payment.booking
        req = booking.request
        booking_id = booking.pk
        title = req.title
        service = _category_name(req.category)
        worker = booking.worker.user.full_name
        lines.append({"label": _("Job price"), "amount": booking.agreed_price})
        if booking.emergency_fee > 0:
            lines.append({"label": _("Emergency fee"), "amount": booking.emergency_fee})
        if payment.discount_amount > 0:
            promo = getattr(payment, "promo_redemption", None)
            label = (_("Discount ({code})").format(code=promo.promo.code) if promo else _("Discount"))
            lines.append({"label": label, "amount": -payment.discount_amount})
    else:
        sub = getattr(payment, "subscription", None)
        listing = getattr(payment, "featured_listing", None)
        if sub:
            title = _("{plan} plan").format(plan=sub.plan.name)
        elif listing:
            title = _("Featured listing: {plan}").format(plan=listing.plan.name)
            service = _category_name(listing.category)
        elif payment.purpose == Payment.Purpose.COMMISSION:
            title = _("Commission owed to KaamNow")
        elif payment.purpose == Payment.Purpose.CANCELLATION_FEE:
            booking = payment.booking
            booking_id = booking.pk
            title = _("Late cancellation fee")
            service = _category_name(booking.request.category)
            worker = booking.worker.user.full_name
        elif payment.purpose == Payment.Purpose.TIP:
            booking = payment.tip.booking
            booking_id = booking.pk
            title = _("Tip for the worker")
            service = _category_name(booking.request.category)
            worker = booking.worker.user.full_name
        lines.append({"label": title or _("Payment"), "amount": payment.amount})
    refunds = [{"date": timezone.localtime(r.created_at).date(), "amount": r.amount, "reference": r.reference}
               for r in payment.refunds.order_by("created_at")]
    return {
        "number": payment.reference,
        "issued_at": payment.confirmed_at or payment.updated_at,
        "status": payment.status,
        "purpose": payment.purpose,
        "booking": booking_id,
        "title": title,
        "service": service,
        "billed_to": payment.payer.full_name,
        "worker": worker,
        "method": payment.method,
        "method_label": method_label(payment.method),
        "transaction_id": payment.gateway_transaction_id,
        "lines": lines,
        "total": payment.amount,
        "refunds": refunds,
        "refunded": payment.refunded_amount,
        "net_paid": payment.amount - payment.refunded_amount,
        "company": settings.RECEIPT_COMPANY,
        "company_address": settings.RECEIPT_ADDRESS,
        "tax_number": settings.RECEIPT_TAX_NUMBER,
    }


def pick_language(request, explicit=""):
    if explicit in ("en", "ur"):
        return explicit
    lang = translation.get_language_from_request(request)
    if lang and lang.startswith("ur"):
        return "ur"
    if request.headers.get("Accept-Language"):
        return "en"
    return getattr(request.user, "language", "en") or "en"


# --- PDF ---------------------------------------------------------------------------
def _fmt_date(dt):
    return timezone.localtime(dt).strftime("%d-%m-%Y %H:%M") if hasattr(dt, "hour") else dt.strftime("%d-%m-%Y")


def render_pdf(payment, lang):
    """The receipt as PDF bytes. Urdu receipts are right-to-left, set in Noto Nastaliq Urdu."""
    from fpdf import FPDF

    with translation.override(lang):
        d = receipt_data(payment)
        urdu = lang == "ur"
        pdf = FPDF(format=(148, 210))  # A5
        pdf.set_auto_page_break(True, margin=12)
        pdf.set_margins(12, 12, 12)
        pdf.add_page()
        pdf.set_title(_("Receipt {number}").format(number=d["number"]))
        pdf.set_author(d["company"])
        pdf.set_creator("KaamNow")
        if urdu:
            pdf.add_font("ur", "", str(FONTS / "NotoNastaliqUrdu-400.ttf"))
            pdf.add_font("ur", "B", str(FONTS / "NotoNastaliqUrdu-700.ttf"))
            pdf.set_text_shaping(use_shaping_engine=True, direction="rtl", script="arab", language="urd")
            family, start, end, line_h = "ur", "R", "L", 9
        else:
            family, start, end, line_h = "helvetica", "L", "R", 6
        width = pdf.epw

        def text(s, size=10, style="", align=None, h=None):
            pdf.set_font(family, style, size)
            pdf.multi_cell(width, h or line_h, s, align=align or start, new_x="LMARGIN", new_y="NEXT")

        def row(label, value, style="", size=10):
            pdf.set_font(family, style, size)
            y = pdf.get_y()
            pdf.multi_cell(width * 0.62, line_h, label, align=start, new_x="LMARGIN", new_y="NEXT")
            after = pdf.get_y()
            pdf.set_y(y)
            x = pdf.l_margin if urdu else pdf.l_margin + width * 0.62
            pdf.set_x(x)
            latin = urdu and not any("\u0600" <= ch <= "\u06ff" for ch in value)
            if latin:  # dates, numbers and IDs read left to right inside an Urdu receipt
                pdf.set_text_shaping(use_shaping_engine=True, direction="ltr")
            pdf.cell(width * 0.38, line_h, value, align=end)
            if latin:
                pdf.set_text_shaping(use_shaping_engine=True, direction="rtl", script="arab", language="urd")
            pdf.set_y(max(after, y + line_h))

        def rule():
            pdf.set_draw_color(200, 200, 200)
            pdf.line(pdf.l_margin, pdf.get_y() + 1, pdf.l_margin + width, pdf.get_y() + 1)
            pdf.ln(3)

        text(d["company"], 16, "B")
        text(d["company_address"], 9)
        if d["tax_number"]:
            text(_("Tax number: {number}").format(number=d["tax_number"]), 9)
        pdf.ln(2)
        text(_("Receipt") if d["status"] == Payment.Status.COMPLETED else _("Receipt (refunded)"), 13, "B")
        row(_("Receipt number"), d["number"], size=9)
        row(_("Date"), _fmt_date(d["issued_at"]), size=9)
        if d["booking"]:
            row(_("Booking"), str(d["booking"]), size=9)
        row(_("Billed to"), d["billed_to"], size=9)
        if d["worker"]:
            row(_("Work done by"), d["worker"], size=9)
        if d["service"]:
            row(_("Service"), d["service"], size=9)
        if d["title"] and d["booking"]:
            row(_("Job"), d["title"], size=9)
        rule()
        for line in d["lines"]:
            row(line["label"], money(line["amount"]))
        rule()
        row(_("Total paid"), money(d["total"]), "B", 11)
        row(_("Paid by"), d["method_label"], size=9)
        if d["transaction_id"]:
            row(_("Transaction ID"), d["transaction_id"], size=9)
        if d["refunds"]:
            rule()
            for r in d["refunds"]:
                row(_("Refund on {date}").format(date=_fmt_date(r["date"])), money(-r["amount"]), size=9)
            row(_("Paid after refunds"), money(d["net_paid"]), "B", 10)
        pdf.ln(4)
        text(_("Thank you for using KaamNow. This receipt was made by computer and needs no signature."), 8,
             align="C")
        return bytes(pdf.output())
