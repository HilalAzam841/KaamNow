from rest_framework import serializers

LEVEL_CHOICES = [("new", "New"), ("rising", "Rising"), ("trusted", "Trusted"), ("top_rated", "Top rated")]
REQUIREMENT_KEYS = [("jobs", "Jobs done"), ("rating", "Average rating"), ("reviews", "Reviews"),
                    ("no_shows", "Confirmed no-shows (90 days)"), ("cancel_rate", "Cancelled by you, % (90 days)")]


class RequirementSerializer(serializers.Serializer):
    key = serializers.ChoiceField(choices=REQUIREMENT_KEYS)
    target = serializers.DecimalField(max_digits=6, decimal_places=1, help_text="Minimum, or maximum for no-shows "
                                      "and cancellations.")
    value = serializers.DecimalField(max_digits=8, decimal_places=2)
    met = serializers.BooleanField()


class LevelStatsSerializer(serializers.Serializer):
    jobs = serializers.IntegerField()
    rating = serializers.DecimalField(max_digits=3, decimal_places=2)
    reviews = serializers.IntegerField()
    no_shows = serializers.IntegerField()
    cancel_rate = serializers.DecimalField(max_digits=5, decimal_places=1)


class LevelProgressSerializer(serializers.Serializer):
    level = serializers.ChoiceField(choices=LEVEL_CHOICES)
    badges = serializers.ListField(child=serializers.CharField())
    next_level = serializers.ChoiceField(choices=LEVEL_CHOICES, allow_null=True)
    requirements = RequirementSerializer(many=True)
    verified = serializers.BooleanField()
    window_days = serializers.IntegerField()
    stats = LevelStatsSerializer()
