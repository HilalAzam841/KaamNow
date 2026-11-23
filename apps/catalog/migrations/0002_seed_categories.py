from django.db import migrations
from django.utils.text import slugify

CATEGORIES = [
    ("Electrician", "electrical"),
    ("Plumber", "plumbing"),
    ("Carpenter", "carpentry"),
    ("AC Technician", "ac"),
    ("Painter", "paint"),
    ("Mechanic", "mechanic"),
    ("Home Cleaning", "cleaning"),
    ("Appliance Repair", "appliance"),
    ("Pest Control", "pest"),
    ("Furniture Repair", "furniture"),
    ("Washing Machine Repair", "washing_machine"),
    ("Refrigerator Repair", "refrigerator"),
    ("Other Services", "other"),
]


def seed(apps, schema_editor):
    ServiceCategory = apps.get_model("catalog", "ServiceCategory")
    for order, (name, icon) in enumerate(CATEGORIES, start=1):
        ServiceCategory.objects.get_or_create(
            slug=slugify(name), defaults={"name": name, "icon": icon, "sort_order": order, "is_active": True}
        )


def unseed(apps, schema_editor):
    ServiceCategory = apps.get_model("catalog", "ServiceCategory")
    ServiceCategory.objects.filter(slug__in=[slugify(n) for n, _ in CATEGORIES], worker_services__isnull=True,
                                   requests__isnull=True).delete()


class Migration(migrations.Migration):
    dependencies = [("catalog", "0001_initial")]
    operations = [migrations.RunPython(seed, unseed)]
