from django.db import migrations
from django.utils.text import slugify

URDU_NAMES = {
    "Electrician": "الیکٹریشن",
    "Plumber": "پلمبر",
    "Carpenter": "بڑھئی",
    "AC Technician": "اے سی ٹیکنیشن",
    "Painter": "پینٹر",
    "Mechanic": "مکینک",
    "Home Cleaning": "گھر کی صفائی",
    "Appliance Repair": "گھریلو آلات کی مرمت",
    "Pest Control": "کیڑے مار سپرے",
    "Furniture Repair": "فرنیچر کی مرمت",
    "Washing Machine Repair": "واشنگ مشین کی مرمت",
    "Refrigerator Repair": "فریج کی مرمت",
    "Other Services": "دیگر خدمات",
}


def seed(apps, schema_editor):
    ServiceCategory = apps.get_model("catalog", "ServiceCategory")
    for name, urdu in URDU_NAMES.items():
        # Only fill blanks, so names an admin already edited are kept.
        ServiceCategory.objects.filter(slug=slugify(name), name_ur="").update(name_ur=urdu)


def unseed(apps, schema_editor):
    ServiceCategory = apps.get_model("catalog", "ServiceCategory")
    for name, urdu in URDU_NAMES.items():
        ServiceCategory.objects.filter(slug=slugify(name), name_ur=urdu).update(name_ur="")


class Migration(migrations.Migration):
    dependencies = [("catalog", "0003_servicecategory_name_ur")]
    operations = [migrations.RunPython(seed, unseed)]
