from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError

from apps.billing.services import calculate_commission
from apps.common.geo import bounding_box, haversine_km
from apps.common.validators import normalize_cnic, normalize_pk_phone


class TestHaversine:
    def test_zero_distance(self):
        assert haversine_km(31.5, 74.3, 31.5, 74.3) == 0

    def test_lahore_to_islamabad_is_about_270_km(self):
        # Lahore (31.5204, 74.3587) -> Islamabad (33.6844, 73.0479)
        d = haversine_km(31.5204, 74.3587, 33.6844, 73.0479)
        assert 265 < d < 275

    def test_short_city_distance(self):
        # Liberty Market -> Gaddafi Stadium is roughly 1.5 km
        d = haversine_km(31.5100, 74.3440, 31.5134, 74.3330)
        assert 0.8 < d < 1.5

    def test_bounding_box_contains_radius(self):
        box = bounding_box(31.5, 74.3, 10)
        assert haversine_km(31.5, 74.3, box.max_lat, 74.3) == pytest.approx(10, rel=1e-3)
        assert haversine_km(31.5, 74.3, 31.5, box.max_lng) == pytest.approx(10, rel=1e-2)


class TestCommission:
    def test_spec_example(self):
        assert calculate_commission(Decimal("2000"), Decimal("10")) == (Decimal("200.00"), Decimal("1800.00"))

    def test_rounding_half_up(self):
        commission, earning = calculate_commission(Decimal("999.99"), Decimal("12.5"))
        assert commission == Decimal("125.00")
        assert earning == Decimal("874.99")
        assert commission + earning == Decimal("999.99")

    def test_zero_rate(self):
        assert calculate_commission(Decimal("500"), Decimal("0")) == (Decimal("0.00"), Decimal("500.00"))

    def test_invalid_rate(self):
        with pytest.raises(ValueError):
            calculate_commission(Decimal("500"), Decimal("150"))


class TestValidators:
    @pytest.mark.parametrize("raw", ["03001234567", "+923001234567", "923001234567", "0300-1234567", "00923001234567"])
    def test_phone_normalisation(self, raw):
        assert normalize_pk_phone(raw) == "+923001234567"

    @pytest.mark.parametrize("raw", ["12345", "04211234567", "+14155552671", ""])
    def test_invalid_phone(self, raw):
        with pytest.raises(ValidationError):
            normalize_pk_phone(raw)

    def test_cnic(self):
        assert normalize_cnic("35202-1234567-1") == "3520212345671"
        with pytest.raises(ValidationError):
            normalize_cnic("35202-12345")
