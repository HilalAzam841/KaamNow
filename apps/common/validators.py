from django.utils.translation import gettext as _
import re

from django.conf import settings
from django.core.exceptions import ValidationError
from PIL import Image, UnidentifiedImageError

PK_MOBILE_RE = re.compile(r"^\+923\d{9}$")
CNIC_RE = re.compile(r"^\d{13}$")

ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}
ALLOWED_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
ALLOWED_DOCUMENT_EXTENSIONS = ALLOWED_IMAGE_EXTENSIONS | {"pdf"}


def normalize_pk_phone(value: str) -> str:
    """Normalise Pakistani mobile numbers to E.164 (+923XXXXXXXXX)."""
    raw = re.sub(r"[\s\-()]", "", str(value or ""))
    if raw.startswith("0092"):
        raw = "+" + raw[2:]
    elif raw.startswith("92"):
        raw = "+" + raw
    elif raw.startswith("03"):
        raw = "+92" + raw[1:]
    if not PK_MOBILE_RE.match(raw):
        raise ValidationError(_("Enter a valid Pakistani mobile number, e.g. 03001234567."))
    return raw


def validate_pk_phone(value):
    if not PK_MOBILE_RE.match(value or ""):
        raise ValidationError(_("Phone number must be in the format +923XXXXXXXXX."))


def normalize_cnic(value: str) -> str:
    raw = str(value or "").replace("-", "").strip()
    if not CNIC_RE.match(raw):
        raise ValidationError(_("CNIC must contain 13 digits, e.g. 35202-1234567-1."))
    return raw


def validate_cnic(value):
    if not CNIC_RE.match(value or ""):
        raise ValidationError(_("CNIC must contain exactly 13 digits."))


def _extension(name):
    return name.rsplit(".", 1)[-1].lower() if "." in name else ""


def _check_size(file, max_mb):
    if file.size > max_mb * 1024 * 1024:
        raise ValidationError(_("File too large. Maximum size is {max_mb} MB.").format(max_mb=max_mb))


def _verify_image(file):
    try:
        pos = file.tell()
        file.seek(0)
        with Image.open(file) as img:
            fmt = img.format
            img.verify()
        file.seek(pos)
    except (UnidentifiedImageError, OSError, SyntaxError) as exc:
        raise ValidationError(_("Upload a valid image file.")) from exc
    if fmt not in ALLOWED_IMAGE_FORMATS:
        raise ValidationError(_("Only JPEG, PNG and WEBP images are allowed."))


def validate_image_upload(file):
    """Validates extension, size and real image content (not just the filename)."""
    if _extension(file.name) not in ALLOWED_IMAGE_EXTENSIONS:
        raise ValidationError(_("Only .jpg, .jpeg, .png and .webp images are allowed."))
    _check_size(file, settings.MAX_IMAGE_UPLOAD_MB)
    _verify_image(file)


def validate_document_upload(file):
    """Validates CNIC/verification documents: images or real PDFs only."""
    ext = _extension(file.name)
    if ext not in ALLOWED_DOCUMENT_EXTENSIONS:
        raise ValidationError(_("Only .jpg, .jpeg, .png, .webp and .pdf files are allowed."))
    _check_size(file, settings.MAX_DOCUMENT_UPLOAD_MB)
    if ext == "pdf":
        pos = file.tell()
        file.seek(0)
        header = file.read(5)
        file.seek(pos)
        if header != b"%PDF-":
            raise ValidationError(_("Upload a valid PDF file."))
    else:
        _verify_image(file)
