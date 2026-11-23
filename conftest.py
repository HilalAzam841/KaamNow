"""Shared pytest fixtures and factories for the KaamNow test-suite."""

import io
from datetime import timedelta
from decimal import Decimal

import pytest
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image
from rest_framework.test import APIClient

from apps.accounts.models import User, WorkerDocument, WorkerProfile
from apps.catalog.models import ServiceCategory, WorkerService

# Liberty Market, Lahore
LAHORE = (Decimal("31.510000"), Decimal("74.344000"))
PASSWORD = "Str0ng-Pass!word"

_counter = {"phone": 0, "cnic": 0}


@pytest.fixture(autouse=True)
def _isolated_settings(settings, tmp_path, monkeypatch):
    settings.MEDIA_ROOT = tmp_path / "media"
    settings.PRIVATE_MEDIA_ROOT = tmp_path / "private"
    settings.PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
    rates = dict(settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
    rates.update({k: "10000/min" for k in rates})
    settings.REST_FRAMEWORK = {**settings.REST_FRAMEWORK, "DEFAULT_THROTTLE_RATES": rates}
    # DRF copies the rates onto the throttle class at import time, so patch there too.
    from rest_framework.throttling import SimpleRateThrottle

    monkeypatch.setattr(SimpleRateThrottle, "THROTTLE_RATES", rates)
    cache.clear()
    yield
    cache.clear()


def next_phone():
    _counter["phone"] += 1
    return f"+92300{_counter['phone']:07d}"


def next_cnic():
    _counter["cnic"] += 1
    return f"35202{_counter['cnic']:08d}"


def make_image(name="photo.jpg", fmt="JPEG", size=(20, 20)):
    buf = io.BytesIO()
    Image.new("RGB", size, (200, 30, 30)).save(buf, format=fmt)
    content_type = {"JPEG": "image/jpeg", "PNG": "image/png"}[fmt]
    return SimpleUploadedFile(name, buf.getvalue(), content_type=content_type)


@pytest.fixture
def api():
    return APIClient()


def client_for(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def category(db):
    # get_or_create: transactional tests flush the seeded data between tests.
    return ServiceCategory.objects.get_or_create(slug="electrician", defaults={"name": "Electrician"})[0]


@pytest.fixture
def other_category(db):
    return ServiceCategory.objects.get_or_create(slug="plumber", defaults={"name": "Plumber"})[0]


@pytest.fixture
def make_customer(db):
    def _make(**kw):
        kw.setdefault("full_name", "Ayesha Khan")
        return User.objects.create_user(phone=next_phone(), password=PASSWORD, role=User.Role.CUSTOMER, **kw)

    return _make


@pytest.fixture
def make_worker(db, category):
    def _make(verified=True, available=True, lat=LAHORE[0], lng=LAHORE[1], radius=Decimal("10"),
              categories=None, name="Bilal Ahmed", experience=5):
        user = User.objects.create_user(phone=next_phone(), password=PASSWORD, role=User.Role.WORKER, full_name=name)
        worker = WorkerProfile.objects.create(
            user=user, cnic_number=next_cnic(), base_latitude=lat, base_longitude=lng, service_radius_km=radius,
            experience_years=experience,
            verification_status=WorkerProfile.VerificationStatus.VERIFIED if verified
            else WorkerProfile.VerificationStatus.PENDING,
            is_available=available,
        )
        for cat in categories if categories is not None else [category]:
            WorkerService.objects.create(worker=worker, category=cat)
        return worker

    return _make


@pytest.fixture
def make_admin(db):
    def _make():
        return User.objects.create_superuser(phone=next_phone(), password=PASSWORD, full_name="Admin User")

    return _make


@pytest.fixture
def customer(make_customer):
    return make_customer()


@pytest.fixture
def worker(make_worker):
    return make_worker()


@pytest.fixture
def admin_user(make_admin):
    return make_admin()


def request_payload(category, lat=LAHORE[0], lng=LAHORE[1], **kw):
    data = {
        "category": category.pk,
        "title": "Ceiling fan not working",
        "description": "The ceiling fan in the bedroom stopped working after a power surge.",
        "latitude": str(lat),
        "longitude": str(lng),
        "address": "House 12, Street 4, Gulberg III, Lahore",
        "area": "Gulberg III",
        "preferred_time": (timezone.now() + timedelta(hours=3)).isoformat(),
    }
    data.update(kw)
    return data


@pytest.fixture
def make_request(db, category):
    from apps.jobs.services import create_service_request

    def _make(customer, cat=None, lat=LAHORE[0], lng=LAHORE[1]):
        return create_service_request(
            customer, category=cat or category, title="Fan repair", description="Fan stopped working suddenly.",
            latitude=lat, longitude=lng, address="House 1, Gulberg, Lahore", area="Gulberg",
            preferred_time=timezone.now() + timedelta(hours=2),
        )

    return _make


@pytest.fixture
def make_offer(db):
    from apps.offers.services import create_offer

    def _make(worker, service_request, price="1000"):
        return create_offer(worker, service_request, price=Decimal(price), estimated_arrival_minutes=30,
                            message="Can come in 30 minutes")

    return _make


@pytest.fixture
def make_booking(make_request, make_offer):
    from apps.offers.services import accept_offer

    def _make(customer, worker, price="1000"):
        req = make_request(customer)
        offer = make_offer(worker, req, price)
        return accept_offer(offer, customer)

    return _make


def advance_to(booking, status_value):
    """Moves a booking through the worker status flow up to `status_value`."""
    from apps.jobs.models import Booking
    from apps.jobs.services import update_booking_status

    order = [Booking.Status.ON_THE_WAY, Booking.Status.ARRIVED, Booking.Status.IN_PROGRESS]
    for s in order:
        booking = update_booking_status(booking, booking.worker.user, s)
        if s == status_value:
            break
    return booking


def data(response):
    """Returns the payload inside the success envelope."""
    body = response.json()
    assert body["success"] is True, body
    return body["data"]


def add_cnic_documents(worker):
    for doc_type in (WorkerDocument.DocumentType.CNIC_FRONT, WorkerDocument.DocumentType.CNIC_BACK):
        WorkerDocument.objects.create(worker=worker, document_type=doc_type, file=make_image(f"{doc_type}.jpg"))
