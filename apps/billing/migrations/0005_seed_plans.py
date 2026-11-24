from decimal import Decimal

from django.db import migrations

# Starting values only. Admins change prices and benefits in the admin API / Django admin.
PLANS = [
    dict(slug="free", name="Free", price=Decimal("0"), duration_days=30, commission_percent=None,
         daily_offer_limit=10, badge="", is_default=True, sort_order=1,
         description="Get started on KaamNow.",
         benefits=["Up to 10 offers per day", "Standard platform commission"]),
    dict(slug="professional", name="Professional", price=Decimal("1500"), duration_days=30,
         commission_percent=Decimal("8.00"), daily_offer_limit=None, badge="PRO", is_default=False, sort_order=2,
         description="For full-time professionals.",
         benefits=["Unlimited offers", "8% commission instead of the standard rate", "PRO badge on your profile"]),
    dict(slug="premium", name="Premium", price=Decimal("3000"), duration_days=30,
         commission_percent=Decimal("6.00"), daily_offer_limit=None, badge="PREMIUM", is_default=False, sort_order=3,
         description="Lowest commission for top earners.",
         benefits=["Unlimited offers", "6% commission", "PREMIUM badge on your profile"]),
]

FEATURED = [
    dict(name="Featured 7 days", duration_days=7, price=Decimal("500")),
    dict(name="Featured 30 days", duration_days=30, price=Decimal("1500")),
]


def seed(apps, schema_editor):
    SubscriptionPlan = apps.get_model("billing", "SubscriptionPlan")
    FeaturedPlan = apps.get_model("billing", "FeaturedPlan")
    for plan in PLANS:
        SubscriptionPlan.objects.get_or_create(slug=plan["slug"], defaults=plan)
    for plan in FEATURED:
        FeaturedPlan.objects.get_or_create(name=plan["name"], defaults=plan)


class Migration(migrations.Migration):
    dependencies = [("billing", "0004_featuredlisting_featuredplan_subscriptionplan_and_more")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
