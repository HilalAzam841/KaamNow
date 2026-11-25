"""Saved addresses: Home, Work and named places a customer posts jobs from.

At most 10 per customer, one Home and one Work, and exactly one default whenever there is at
least one (the first saved becomes the default; deleting the default promotes the oldest left).
"""

from django.db import IntegrityError, transaction
from django.utils.translation import gettext as _
from rest_framework import status as http_status

from apps.common.exceptions import BusinessRuleError

from .models import SavedAddress

MAX_ADDRESSES = 10


def _label_taken(user, label, exclude=None):
    if label == SavedAddress.Label.OTHER:
        return False
    qs = SavedAddress.objects.filter(user=user, label=label)
    if exclude is not None:
        qs = qs.exclude(pk=exclude.pk)
    return qs.exists()


def _refuse_label(label):
    raise BusinessRuleError(
        _("You already saved a Home address. Edit that one instead.") if label == SavedAddress.Label.HOME
        else _("You already saved a Work address. Edit that one instead."),
        status_code=http_status.HTTP_409_CONFLICT)


@transaction.atomic
def _set_default(address):
    SavedAddress.objects.filter(user=address.user_id, is_default=True).exclude(pk=address.pk).update(is_default=False)
    if not address.is_default:
        address.is_default = True
        address.save(update_fields=["is_default", "updated_at"])
    return address


@transaction.atomic
def add(user, *, make_default=False, **fields):
    type(user).objects.select_for_update().filter(pk=user.pk).first()
    existing = SavedAddress.objects.filter(user=user)
    if existing.count() >= MAX_ADDRESSES:
        raise BusinessRuleError(_("You can save up to 10 addresses. Delete one first."))
    if _label_taken(user, fields["label"]):
        _refuse_label(fields["label"])
    first = not existing.exists()
    try:
        address = SavedAddress.objects.create(user=user, **fields)
    except IntegrityError:
        _refuse_label(fields["label"])
    if first or make_default:
        _set_default(address)
    return address


@transaction.atomic
def update(address, *, make_default=False, **fields):
    if "label" in fields and _label_taken(address.user, fields["label"], exclude=address):
        _refuse_label(fields["label"])
    for key, value in fields.items():
        setattr(address, key, value)
    if fields:
        address.save()
    if make_default:
        _set_default(address)
    return address


def make_default(address):
    return _set_default(address)


@transaction.atomic
def delete(address):
    user_id, was_default = address.user_id, address.is_default
    address.delete()
    if was_default:
        nxt = SavedAddress.objects.filter(user_id=user_id).order_by("created_at").first()
        if nxt is not None:
            _set_default(nxt)
