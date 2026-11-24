"""Creates demo accounts for local development and mobile-app testing.

    python manage.py seed_demo_data

Never run this in production.
"""

from decimal import Decimal

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import User, WorkerProfile
from apps.catalog.models import ServiceCategory, WorkerService

DEMO_PASSWORD = "KaamNow-Demo-2026"

WORKERS = [
    # name, phone, cnic, lat, lng, area, categories, experience
    ("Bilal Ahmed", "+923001000001", "3520210000011", "31.510000", "74.344000", "Gulberg", ["electrician", "ac-technician"], 8),
    ("Usman Tariq", "+923001000002", "3520210000022", "31.470000", "74.270000", "Johar Town", ["plumber"], 5),
    ("Kashif Mehmood", "+923001000003", "3520210000033", "31.480000", "74.400000", "DHA Phase 5", ["electrician", "appliance-repair"], 12),
    ("Imran Ali", "+923001000004", "3520210000044", "31.560000", "74.320000", "Shadman", ["carpenter", "furniture-repair"], 3),
]


class Command(BaseCommand):
    help = "Create demo admin, customer and verified worker accounts around Lahore."

    def add_arguments(self, parser):
        parser.add_argument("--force", action="store_true", help="Allow running with DEBUG=False.")

    @transaction.atomic
    def handle(self, *args, **options):
        if not settings.DEBUG and not options["force"]:
            raise CommandError("Refusing to seed demo data with DEBUG=False (use --force for staging).")

        admin, created = User.objects.get_or_create(
            phone="+923000000001",
            defaults={"full_name": "KaamNow Admin", "role": User.Role.ADMIN, "is_staff": True, "is_superuser": True},
        )
        if created:
            admin.set_password(DEMO_PASSWORD)
            admin.save()

        customer, created = User.objects.get_or_create(
            phone="+923000000002", defaults={"full_name": "Ayesha Khan", "role": User.Role.CUSTOMER}
        )
        if created:
            customer.set_password(DEMO_PASSWORD)
            customer.save()

        # Demo numbers are not real phones, so they count as already confirmed.
        User.objects.filter(phone__in=["+923000000001", "+923000000002"], phone_verified_at__isnull=True).update(
            phone_verified_at=timezone.now()
        )

        for name, phone, cnic, lat, lng, area, slugs, exp in WORKERS:
            user, created = User.objects.get_or_create(phone=phone, defaults={"full_name": name, "role": User.Role.WORKER})
            if created:
                user.set_password(DEMO_PASSWORD)
                user.save()
            User.objects.filter(pk=user.pk, phone_verified_at__isnull=True).update(phone_verified_at=timezone.now())
            profile, _ = WorkerProfile.objects.update_or_create(
                user=user,
                defaults={
                    "cnic_number": cnic, "base_latitude": Decimal(lat), "base_longitude": Decimal(lng),
                    "service_area": f"{area}, Lahore", "service_radius_km": Decimal("15"), "experience_years": exp,
                    "verification_status": WorkerProfile.VerificationStatus.VERIFIED, "is_available": True,
                    "verified_by": admin, "bio": f"{exp} years of experience in {area}.",
                },
            )
            for slug in slugs:
                category = ServiceCategory.objects.get(slug=slug)
                WorkerService.objects.get_or_create(worker=profile, category=category)

        self.stdout.write(self.style.SUCCESS(
            f"Demo data ready. Password for all demo accounts: {DEMO_PASSWORD}\n"
            "  Admin:    +923000000001\n  Customer: +923000000002\n"
            "  Workers:  +923001000001 .. +923001000004 (verified, online)"
        ))
