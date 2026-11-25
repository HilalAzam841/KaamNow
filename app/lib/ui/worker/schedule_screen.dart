import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

/// Weekday name for 0 = Monday .. 6 = Sunday, in the current language.
String weekdayName(BuildContext context, int weekday) =>
    DateFormat.EEEE(context.t.localeName).format(DateTime(2024, 1, 1 + weekday)); // 1 Jan 2024 was a Monday

TimeOfDay parseHm(String hm) {
  final p = hm.split(':');
  return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

String formatHm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String hmLabel(BuildContext context, String hm) {
  final t = parseHm(hm);
  return clock(DateTime(2024, 1, 1, t.hour, t.minute));
}

/// "Mon to Sat, 9:00 AM to 6:00 PM" style lines for a public profile.
List<String> hoursSummary(BuildContext context, List<WorkingHours> hours) => [
      for (final h in [...hours]..sort((a, b) => a.weekday.compareTo(b.weekday)))
        '${weekdayName(context, h.weekday)}: ${context.t.timeRange(hmLabel(context, h.start), hmLabel(context, h.end))}',
    ];

/// The worker's weekly hours and days off. Jobs are only offered inside them.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.myScheduleTitle)),
      body: PageBody(
        child: Loader<WorkerSchedule>(
          load: api.mySchedule,
          builder: (context, s, reload) => _ScheduleForm(initial: s, reload: reload),
        ),
      ),
    );
  }
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({required this.initial, required this.reload});
  final WorkerSchedule initial;
  final Future<void> Function() reload;

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  /// Any time (no hours set) or set hours per day.
  late bool _anyTime;
  final Map<int, WorkingHours> _days = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _anyTime = widget.initial.hours.isEmpty;
    for (final h in widget.initial.hours) {
      _days[h.weekday] = h;
    }
    if (_anyTime) {
      // A sensible starting point when the worker switches to set hours: Monday to Saturday, 9 to 6.
      for (var d = 0; d < 6; d++) {
        _days[d] = WorkingHours(weekday: d, start: '09:00', end: '18:00');
      }
    }
  }

  Future<void> _pick(int weekday, {required bool start}) async {
    final h = _days[weekday]!;
    final picked = await showTimePicker(context: context, initialTime: parseHm(start ? h.start : h.end));
    if (picked == null) return;
    setState(() => _days[weekday] = WorkingHours(
        weekday: weekday, start: start ? formatHm(picked) : h.start, end: start ? h.end : formatHm(picked)));
  }

  Future<void> _save() async {
    final t = context.t;
    final hours = _anyTime ? <WorkingHours>[] : (_days.values.toList()..sort((a, b) => a.weekday.compareTo(b.weekday)));
    if (!_anyTime && hours.isEmpty) return showInfo(context, t.chooseOneWorkingDay);
    for (final h in hours) {
      if (h.end.compareTo(h.start) <= 0) {
        return showInfo(context, t.endAfterStartFor(weekdayName(context, h.weekday)));
      }
    }
    setState(() => _saving = true);
    final r = await runAction(context, () => context.read<Session>().api.saveHours(hours), success: t.scheduleSaved);
    if (mounted) setState(() => _saving = false);
    if (r != null) widget.reload();
  }

  Future<void> _addTimeOff() async {
    final t = context.t;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: t.chooseDaysOff,
    );
    if (range == null || !mounted) return;
    final reason = await promptText(context, t.timeOffReasonTitle, label: t.timeOffReasonLabel, ok: t.save);
    if (reason == null || !mounted) return;
    final r = await runAction(context, () => context.read<Session>().api.addTimeOff(range.start, range.end, reason: reason),
        success: t.timeOffAdded);
    if (r != null) widget.reload();
  }

  Future<void> _deleteTimeOff(TimeOffEntry o) async {
    final t = context.t;
    if (!await confirm(context, t.removeTimeOffTitle, t.removeTimeOffBody, ok: t.remove)) return;
    if (!mounted) return;
    final r = await runAction(context, () async {
      await context.read<Session>().api.deleteTimeOff(o.id);
      return true;
    });
    if (r != null) widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(t.scheduleExplain, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      SwitchListTile(
        key: const Key('schedule-any-time'),
        contentPadding: EdgeInsets.zero,
        value: _anyTime,
        onChanged: (v) => setState(() => _anyTime = v),
        title: Text(t.availableAnyTime),
        subtitle: Text(t.availableAnyTimeHelp),
      ),
      if (!_anyTime) ...[
        SectionTitle(t.workingHours),
        for (var d = 0; d < 7; d++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Switch(
                key: Key('schedule-day-$d'),
                value: _days.containsKey(d),
                onChanged: (on) => setState(() {
                  if (on) {
                    _days[d] = WorkingHours(weekday: d, start: '09:00', end: '18:00');
                  } else {
                    _days.remove(d);
                  }
                }),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(weekdayName(context, d))),
              if (_days[d] != null) ...[
                TextButton(
                  key: Key('schedule-start-$d'),
                  onPressed: () => _pick(d, start: true),
                  child: Text(hmLabel(context, _days[d]!.start)),
                ),
                Text(t.toWord),
                TextButton(
                  key: Key('schedule-end-$d'),
                  onPressed: () => _pick(d, start: false),
                  child: Text(hmLabel(context, _days[d]!.end)),
                ),
              ] else
                Text(t.dayOff, style: theme.textTheme.bodySmall),
            ]),
          ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        key: const Key('schedule-save'),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(t.saveHours),
      ),
      SectionTitle(t.timeOff),
      Text(t.timeOffExplain, style: theme.textTheme.bodySmall),
      if (widget.initial.timeOff.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t.noTimeOff))
      else
        for (final o in widget.initial.timeOff)
          ListTile(
            key: Key('time-off-${o.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: Text(o.startDate == o.endDate ? day(o.startDate) : t.dateRange(day(o.startDate), day(o.endDate))),
            subtitle: o.reason.isEmpty ? null : Text(o.reason),
            trailing: IconButton(
              tooltip: t.remove,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteTimeOff(o),
            ),
          ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const Key('time-off-add'),
          onPressed: _addTimeOff,
          icon: const Icon(Icons.add),
          label: Text(t.addTimeOff),
        ),
      ),
      const SizedBox(height: 32),
    ]);
  }
}
