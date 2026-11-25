import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

const frequencies = ['weekly', 'biweekly', 'monthly'];

String frequencyLabel(String f) => switch (f) {
      'weekly' => strings.freqWeekly,
      'biweekly' => strings.freqBiweekly,
      'monthly' => strings.freqMonthly,
      _ => humanize(f),
    };

/// The default first repeat: one period after the booked visit, at the same time of day,
/// moved forward until it is at least a day away.
DateTime defaultFirstVisit(DateTime? booked, String frequency, {DateTime? now}) {
  now ??= DateTime.now();
  var t = (booked ?? now).toLocal();
  DateTime next(DateTime d) => switch (frequency) {
        'biweekly' => DateTime(d.year, d.month, d.day + 14, d.hour, d.minute),
        'monthly' => DateTime(d.year, d.month + 1, d.day.clamp(1, 28), d.hour, d.minute),
        _ => DateTime(d.year, d.month, d.day + 7, d.hour, d.minute),
      };
  do {
    t = next(t);
  } while (t.isBefore(now.add(const Duration(days: 1))));
  return t;
}

/// Bottom sheet that turns a booking into a repeating job. Returns true when created.
Future<bool> showRepeatJobSheet(BuildContext context, Booking booking) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RepeatSheet(booking: booking),
  );
  return created == true;
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.booking});
  final Booking booking;
  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  String _frequency = 'weekly';
  late DateTime _first = defaultFirstVisit(widget.booking.preferredTime, _frequency);
  bool _changedTime = false;
  bool _busy = false;

  Future<void> _pick() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context, firstDate: now, lastDate: now.add(const Duration(days: 59)), initialDate: _first);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_first));
    if (time == null) return;
    setState(() {
      _first = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _changedTime = true;
    });
  }

  Future<void> _submit() async {
    final t = context.t;
    setState(() => _busy = true);
    final plan = await runAction(context,
        () => context.read<Session>().api.repeatBooking(widget.booking.id, _frequency, _first),
        success: t.jobNowRepeats);
    if (!mounted) return;
    setState(() => _busy = false);
    if (plan != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final b = widget.booking;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.repeatThisJob, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(b.title),
        const SizedBox(height: 16),
        Text(t.howOften, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in frequencies)
            ChoiceChip(
              key: Key('freq-$f'),
              label: Text(frequencyLabel(f)),
              selected: _frequency == f,
              onSelected: (_) => setState(() {
                _frequency = f;
                if (!_changedTime) _first = defaultFirstVisit(b.preferredTime, f);
              }),
            ),
        ]),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('first-visit'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(t.firstVisit),
          subtitle: Text(whenWindow(_first, b.durationMinutes)),
          trailing: TextButton(onPressed: _pick, child: Text(t.change)),
        ),
        Text(t.repeatSheetHint(b.worker.fullName.split(' ').first), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('start-repeating'),
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.repeat),
          label: Text(t.startRepeating),
        ),
      ]),
    );
  }
}

/// Customers: their repeating jobs with pause, skip, change and stop.
/// Workers: the jobs they are the usual worker for, with a way to step away.
class RecurringJobsScreen extends StatefulWidget {
  const RecurringJobsScreen({super.key});
  @override
  State<RecurringJobsScreen> createState() => _RecurringJobsScreenState();
}

class _RecurringJobsScreenState extends State<RecurringJobsScreen> {
  final _loader = GlobalKey<LoaderState<List<RecurringJob>>>();

  Future<void> _reload() async => _loader.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final isWorker = session.user?.isWorker == true;
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.repeatingJobs)),
      body: PageBody(
        child: Loader<List<RecurringJob>>(
          key: _loader,
          load: () async => (await session.api.recurringJobs()).where((p) => p.status != 'cancelled').toList(),
          builder: (context, plans, reload) {
            if (plans.isEmpty) {
              return EmptyView(
                icon: Icons.repeat,
                title: t.noRepeatingJobs,
                subtitle: isWorker ? t.noRepeatingJobsWorker : t.noRepeatingJobsCustomer,
              );
            }
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                for (final p in plans)
                  isWorker ? _WorkerPlanCard(plan: p, onChanged: _reload) : _CustomerPlanCard(plan: p, onChanged: _reload),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan, required this.subtitle, this.trailing});
  final RecurringJob plan;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final text = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.title, style: text.titleMedium),
          Text('${p.categoryName} · ${frequencyLabel(p.frequency)}', style: text.bodySmall),
          const SizedBox(height: 4),
          Text(subtitle),
          if (p.nextVisit != null && p.isActive)
            Text(context.t.nextVisitOn(whenWindow(p.nextVisit, p.durationMinutes)),
                key: Key('next-visit-${p.id}'), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      StatusChip(p.status, label: p.isPaused ? context.t.statusPaused : null),
      ?trailing,
    ]);
  }
}

class _CustomerPlanCard extends StatelessWidget {
  const _CustomerPlanCard({required this.plan, required this.onChanged});
  final RecurringJob plan;
  final Future<void> Function() onChanged;

  Future<void> _act(BuildContext context, String action) async {
    final t = context.t;
    final api = context.read<Session>().api;
    if (action == 'cancel' && !await confirm(context, t.stopRepeatingQ, t.stopRepeatingBody, ok: t.stopRepeating)) {
      return;
    }
    if (!context.mounted) return;
    final r = await runAction(context, () => api.recurringAction(plan.id, action), success: switch (action) {
      'pause' => t.pausedRepeating,
      'resume' => t.resumedRepeating,
      'skip-next' => t.skippedNextVisit,
      _ => t.stoppedRepeating,
    });
    if (r != null) await onChanged();
  }

  Future<void> _changeFrequency(BuildContext context) async {
    final t = context.t;
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(t.howOften), children: [
        for (final f in frequencies)
          SimpleDialogOption(
            key: Key('set-freq-$f'),
            onPressed: () => Navigator.pop(c, f),
            child: Row(children: [
              Icon(f == plan.frequency ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
              const SizedBox(width: 12),
              Text(frequencyLabel(f)),
            ]),
          ),
      ]),
    );
    if (picked == null || picked == plan.frequency || !context.mounted) return;
    final r = await runAction(context, () => context.read<Session>().api.updateRecurring(plan.id, {'frequency': picked}));
    if (r != null) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = plan;
    return Card(
      key: Key('plan-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PlanHeader(
            plan: p,
            subtitle: p.workerName == null ? t.anyWorkerNearby : t.withWorkerName(p.workerName!),
            trailing: PopupMenuButton<String>(
              key: Key('plan-menu-${p.id}'),
              onSelected: (v) => v == 'frequency' ? _changeFrequency(context) : _act(context, v),
              itemBuilder: (_) => [
                if (p.isActive) PopupMenuItem(value: 'skip-next', child: Text(t.skipNextVisit)),
                PopupMenuItem(value: 'frequency', child: Text(t.changeHowOften)),
                if (p.isActive) PopupMenuItem(value: 'pause', child: Text(t.pauseRepeating)),
                if (p.isPaused) PopupMenuItem(value: 'resume', child: Text(t.resumeRepeating)),
                PopupMenuItem(value: 'cancel', child: Text(t.stopRepeating)),
              ],
            ),
          ),
          if (p.recentVisits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.recentVisits, style: Theme.of(context).textTheme.labelLarge),
            for (final v in p.recentVisits.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (v.outcome) {
                  'worker' => Icons.person,
                  'all' => Icons.groups,
                  _ => Icons.error_outline,
                }, size: 18),
                title: Text(day(v.scheduledFor)),
                subtitle: Text(switch (v.outcome) {
                  'worker' => t.visitSentToWorker,
                  'all' => t.visitSentToAll,
                  _ => v.note.isEmpty ? t.visitFailed : v.note,
                }),
                onTap: v.bookingId != null
                    ? () => context.push('/bookings/${v.bookingId}')
                    : v.requestId != null
                        ? () => context.push('/requests/${v.requestId}')
                        : null,
              ),
          ],
          if (p.isPaused)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                  key: Key('resume-${p.id}'), onPressed: () => _act(context, 'resume'), child: Text(t.resumeRepeating)),
            ),
        ]),
      ),
    );
  }
}

class _WorkerPlanCard extends StatelessWidget {
  const _WorkerPlanCard({required this.plan, required this.onChanged});
  final RecurringJob plan;
  final Future<void> Function() onChanged;

  Future<void> _leave(BuildContext context) async {
    final t = context.t;
    if (!await confirm(context, t.leaveRepeatingQ, t.leaveRepeatingBody(plan.customerName), ok: t.cantDoThisAnyMore)) {
      return;
    }
    if (!context.mounted) return;
    final r = await runAction(context, () => context.read<Session>().api.recurringAction(plan.id, 'leave'),
        success: t.leftRepeating);
    if (r != null) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return Card(
      key: Key('plan-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PlanHeader(plan: p, subtitle: [p.customerName, p.area].where((s) => s.isNotEmpty).join(' · ')),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
                key: Key('leave-${p.id}'), onPressed: () => _leave(context), child: Text(context.t.cantDoThisAnyMore)),
          ),
        ]),
      ),
    );
  }
}
