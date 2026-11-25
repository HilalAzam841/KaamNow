"""Worker working hours and time off.

A worker with no working hours set is treated as available any time (as before this feature);
time off and existing bookings still apply.
"""

from django.db import models
from django.db.models import F, Q

from apps.common.models import TimeStampedModel


class WorkingHours(models.Model):
    class Weekday(models.IntegerChoices):
        MONDAY = 0, "Monday"
        TUESDAY = 1, "Tuesday"
        WEDNESDAY = 2, "Wednesday"
        THURSDAY = 3, "Thursday"
        FRIDAY = 4, "Friday"
        SATURDAY = 5, "Saturday"
        SUNDAY = 6, "Sunday"

    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="working_hours")
    weekday = models.PositiveSmallIntegerField(choices=Weekday.choices)
    start_time = models.TimeField()
    end_time = models.TimeField()

    class Meta:
        ordering = ["weekday"]
        constraints = [
            models.UniqueConstraint(fields=["worker", "weekday"], name="one_working_hours_per_weekday"),
            models.CheckConstraint(condition=Q(end_time__gt=F("start_time")), name="working_hours_end_after_start"),
        ]

    def __str__(self):
        return f"{self.worker_id} {self.get_weekday_display()} {self.start_time}-{self.end_time}"


class TimeOff(TimeStampedModel):
    worker = models.ForeignKey("accounts.WorkerProfile", on_delete=models.CASCADE, related_name="time_off")
    start_date = models.DateField()
    end_date = models.DateField()
    reason = models.CharField(max_length=120, blank=True)

    class Meta:
        ordering = ["start_date"]
        constraints = [
            models.CheckConstraint(condition=Q(end_date__gte=F("start_date")), name="time_off_end_not_before_start"),
        ]
