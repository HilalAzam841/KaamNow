from decimal import Decimal

from django.db import migrations


def create_default(apps, schema_editor):
    PlatformSettings = apps.get_model("billing", "PlatformSettings")
    PlatformSettings.objects.get_or_create(pk=1, defaults={"commission_percent": Decimal("10.00")})


class Migration(migrations.Migration):
    dependencies = [("billing", "0002_initial")]
    operations = [migrations.RunPython(create_default, migrations.RunPython.noop)]
