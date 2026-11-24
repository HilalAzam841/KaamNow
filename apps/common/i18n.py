"""Helpers for alerts that are rendered later in the recipient's language.

Build titles and bodies with `t()` (a lazy gettext with named placeholders). They are turned
into text by `apps.notifications.services.notify()`, inside the recipient's language.
"""

from decimal import Decimal

from django.utils.functional import lazy
from django.utils.text import format_lazy
from django.utils.translation import gettext_lazy


def t(message, **params):
    """Lazy translated text with {named} placeholders. Params may be lazy too."""
    return format_lazy(gettext_lazy(message), **params) if params else gettext_lazy(message)


def format_amount(amount):
    """1500.00 -> "1,500"; 1500.50 -> "1,500.50"."""
    value = Decimal(str(amount))
    return f"{value:,.0f}" if value == value.to_integral_value() else f"{value:,.2f}"


def money(amount):
    return t("Rs. {amount}", amount=format_amount(amount))


def _category_name(category):
    return category.display_name


category_name = lazy(_category_name, str)
"""The category's name in whatever language is active when the text is rendered."""
