from django.db import transaction
from django.db.models import F
from django.utils.translation import gettext as _

from apps.accounts.models import WorkerProfile
from apps.common.exceptions import BusinessRuleError, ConflictError
from apps.common.i18n import money, t
from apps.jobs.models import ServiceRequest
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import MAX_INCLUDES, MAX_PACKAGES, ServicePackage


def public_packages():
    """Packages customers can see and book: active, not hidden, from a verified worker who still
    offers that service, in an active category."""
    return (
        ServicePackage.objects.filter(
            is_active=True, is_hidden=False, category__is_active=True,
            worker__verification_status=WorkerProfile.VerificationStatus.VERIFIED,
            worker__user__is_active=True, worker__user__is_suspended=False,
            worker__services__category=F("category"), worker__services__is_active=True,
        )
        .select_related("worker__user", "category")
        .distinct()
    )


def _check_category(worker, category):
    if not category.is_active:
        raise BusinessRuleError(_("This service category is not available."))
    if not worker.services.filter(category=category, is_active=True).exists():
        raise BusinessRuleError(
            _("Add {category} to your services before making a package for it.").format(
                category=category.display_name),
            code="service_not_offered",
        )


def _clean_includes(lines):
    lines = [str(x).strip() for x in (lines or []) if str(x).strip()]
    if len(lines) > MAX_INCLUDES:
        raise BusinessRuleError(_("List up to {n} things the price covers.").format(n=MAX_INCLUDES))
    if any(len(x) > 80 for x in lines):
        raise BusinessRuleError(_("Keep each line under 80 characters."))
    return lines


def _validate_price(amount):
    from apps.offers.services import validate_price

    return validate_price(amount)


@transaction.atomic
def create_package(worker, **data):
    WorkerProfile.objects.select_for_update().get(pk=worker.pk)  # one package at a time, so the limit holds
    if ServicePackage.objects.filter(worker=worker).count() >= MAX_PACKAGES:
        raise BusinessRuleError(_("You can have up to {n} packages. Delete one to add another.").format(
            n=MAX_PACKAGES), code="too_many_packages")
    _check_category(worker, data["category"])
    data["price"] = _validate_price(data["price"])
    data["includes"] = _clean_includes(data.get("includes"))
    return ServicePackage.objects.create(worker=worker, **data)


def update_package(package, **data):
    if "category" in data and data["category"].pk != package.category_id:
        _check_category(package.worker, data["category"])
    if "price" in data:
        data["price"] = _validate_price(data["price"])
    if "includes" in data:
        data["includes"] = _clean_includes(data["includes"])
    for field, value in data.items():
        setattr(package, field, value)
    package.save()
    return package


def worker_covers(worker, latitude, longitude):
    from apps.common.geo import haversine_km

    if worker.base_latitude is None or worker.base_longitude is None:
        return False
    distance = haversine_km(worker.base_latitude, worker.base_longitude, latitude, longitude)
    return distance <= float(worker.service_radius_km)


def book_package(customer, package, *, preferred_time, latitude, longitude, address, area="", notes=""):
    """Books a package straight away at its fixed price.

    Builds the same request, offer and booking rows as a normal job, so tracking, chat, payment,
    receipts and reviews all work unchanged. The worker must be free at that time and cover the
    address. Everything happens in one transaction: if any check fails nothing is saved.
    """
    from apps.accounts.phone import require_verified
    from apps.jobs.services import check_worker_can_be_invited, worker_distance_to_request
    from apps.offers.models import Party, WorkerOffer
    from apps.offers.services import accept_offer

    require_verified(customer)
    with transaction.atomic():
        package = (
            ServicePackage.objects.select_for_update(of=("self",))
            .select_related("worker__user", "category").get(pk=package.pk)
        )
        if not public_packages().filter(pk=package.pk).exists():
            raise ConflictError(_("This package is not available right now."), code="package_unavailable")
        worker = package.worker
        if ServiceRequest.objects.filter(
            customer=customer, package=package, preferred_time=preferred_time,
            status__in=[ServiceRequest.Status.OPEN, ServiceRequest.Status.BOOKED],
        ).exists():
            raise ConflictError(_("You already booked this package for that time."), code="duplicate_booking")

        description = package.description or package.title
        if package.includes:
            description += "\n" + "\n".join(f"- {line}" for line in package.includes)
        if notes:
            description += "\n\n" + _("Customer notes: {notes}").format(notes=notes)
        service_request = ServiceRequest.objects.create(
            customer=customer, category=package.category, title=package.title, description=description[:3000],
            latitude=latitude, longitude=longitude, address=address, area=area, preferred_time=preferred_time,
            duration_minutes=package.duration_minutes, budget=package.price, invited_worker=worker,
            package=package,
        )
        check_worker_can_be_invited(worker, service_request)
        offer = WorkerOffer.objects.create(
            request=service_request, worker=worker, initial_price=package.price, current_price=package.price,
            awaiting=Party.CUSTOMER, estimated_arrival_minutes=0, message=package.title[:500],
            distance_km=worker_distance_to_request(worker, service_request),
        )
        booking = accept_offer(offer, customer, notify_worker=False)
        ServicePackage.objects.filter(pk=package.pk).update(times_booked=F("times_booked") + 1)
        notify(
            worker.user, Notification.Type.OFFER_ACCEPTED, t("New package booking"),
            t("{name} booked your package '{title}' for {amount}. Booking #{id} is confirmed.",
              name=customer.full_name.split(" ")[0], title=package.title, amount=money(package.price), id=booking.pk),
            {"booking_id": booking.pk, "package_id": package.pk},
        )
        return booking


def hide(package, admin, reason):
    package.is_hidden, package.hidden_reason, package.hidden_by = True, reason, admin
    package.save(update_fields=["is_hidden", "hidden_reason", "hidden_by", "updated_at"])
    notify(
        package.worker.user, Notification.Type.SYSTEM, t("Package hidden"),
        t("An admin hid your package '{title}': {reason}", title=package.title, reason=reason),
        {"package_id": package.pk},
    )
    return package


def unhide(package, admin):
    package.is_hidden, package.hidden_reason, package.hidden_by = False, "", None
    package.save(update_fields=["is_hidden", "hidden_reason", "hidden_by", "updated_at"])
    return package


def in_area(packages, latitude, longitude):
    """Keeps the packages whose worker covers this point."""
    return [p for p in packages if worker_covers(p.worker, latitude, longitude)]

