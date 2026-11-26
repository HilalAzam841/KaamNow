import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/kaamnow_api.dart' show isoDate;
import '../../core/file_saver.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';

typedef SaveFile = Future<bool> Function(Uint8List bytes, String filename, String contentType);

enum ReportPeriod { thisWeek, thisMonth, lastMonth, thisYear, custom }

/// The first and last day of [p], counted from [today].
(DateTime, DateTime) periodRange(ReportPeriod p, DateTime today) {
  final d = DateTime(today.year, today.month, today.day);
  return switch (p) {
    ReportPeriod.thisWeek => (d.subtract(Duration(days: d.weekday - 1)), d),
    ReportPeriod.thisMonth || ReportPeriod.custom => (DateTime(d.year, d.month), d),
    ReportPeriod.lastMonth => (DateTime(d.year, d.month - 1), DateTime(d.year, d.month, 0)),
    ReportPeriod.thisYear => (DateTime(d.year), d),
  };
}

/// Change from the previous period, in whole percent; null when there was nothing before.
int? changePercent(String now, String before) {
  final a = double.tryParse(now) ?? 0, b = double.tryParse(before) ?? 0;
  if (b <= 0) return null;
  return ((a - b) / b * 100).round();
}

/// A worker's earnings for a chosen period, compared with the period before.
class EarningsReportScreen extends StatefulWidget {
  const EarningsReportScreen({super.key, this.today, this.save = saveBytes});

  /// For tests; defaults to now.
  final DateTime? today;
  final SaveFile save;

  @override
  State<EarningsReportScreen> createState() => _EarningsReportScreenState();
}

class _EarningsReportScreenState extends State<EarningsReportScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  ReportPeriod _period = ReportPeriod.thisMonth;
  late (DateTime, DateTime) _range = periodRange(_period, _today);
  EarningsReport? _report;
  Object? _error;
  bool _loading = true;
  bool _downloading = false;
  int _call = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final call = ++_call;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<Session>().api.earningsReport(start: _range.$1, end: _range.$2);
      if (mounted && call == _call) setState(() => _report = r);
    } catch (e) {
      if (mounted && call == _call) setState(() => _error = e);
    } finally {
      if (mounted && call == _call) setState(() => _loading = false);
    }
  }

  Future<void> _choose(ReportPeriod p) async {
    if (p == ReportPeriod.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(_today.year - 3),
        lastDate: _today,
        initialDateRange: DateTimeRange(start: _range.$1, end: _range.$2),
      );
      if (picked == null || !mounted) return;
      var start = picked.start;
      if (picked.end.difference(start).inDays > 365) start = picked.end.subtract(const Duration(days: 365));
      setState(() {
        _period = p;
        _range = (start, picked.end);
      });
    } else {
      setState(() {
        _period = p;
        _range = periodRange(p, _today);
      });
    }
    await _load();
  }

  Future<void> _download() async {
    final t = context.t;
    setState(() => _downloading = true);
    final api = context.read<Session>().api;
    final ok = await runAction(context, () async {
      final (bytes, type) = await api.earningsStatement(start: _range.$1, end: _range.$2);
      return widget.save(bytes, 'kaamnow-earnings-${isoDate(_range.$1)}-to-${isoDate(_range.$2)}.csv', type);
    });
    if (!mounted) return;
    setState(() => _downloading = false);
    if (ok == true) showInfo(context, t.statementReady);
  }

  String _periodLabel(ReportPeriod p) => switch (p) {
        ReportPeriod.thisWeek => context.t.periodThisWeek,
        ReportPeriod.thisMonth => context.t.periodThisMonth,
        ReportPeriod.lastMonth => context.t.periodLastMonth,
        ReportPeriod.thisYear => context.t.periodThisYear,
        ReportPeriod.custom => context.t.periodCustom,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: Text(t.earningsReports), actions: const [LanguageButton()]),
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final p in ReportPeriod.values)
                ChoiceChip(
                  key: Key('period-${p.name}'),
                  label: Text(_periodLabel(p)),
                  selected: _period == p,
                  onSelected: (_) => _choose(p),
                ),
            ]),
            const SizedBox(height: 8),
            Text(t.periodRange(day(_range.$1), day(_range.$2)), key: const Key('report-range'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (_loading && r == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && r == null)
              ErrorView(error: _error!, onRetry: _load)
            else if (r != null) ...[
              if (_loading) const LinearProgressIndicator(),
              _Summary(report: r),
              if (r.totals.jobs == 0)
                Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(t.reportEmpty, textAlign: TextAlign.center))
              else ...[
                SectionTitle(t.reportByTime),
                EarningsBars(report: r),
                SectionTitle(t.reportByService),
                _Shares(rows: [for (final s in r.byService) (s.name, s.jobs, s.net)], total: r.totals.earnings),
                SectionTitle(t.reportByPayment),
                _Shares(rows: [
                  for (final (k, label) in [('cash', t.reportCash), ('online', t.reportOnline), ('unpaid', t.reportUnpaid)])
                    if ((r.byPayment[k]?.jobs ?? 0) > 0) (label, r.byPayment[k]!.jobs, r.byPayment[k]!.net),
                ], total: r.totals.earnings),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('download-statement'),
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(t.downloadStatement),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.report});
  final EarningsReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final r = report;
    final change = changePercent(r.totals.net, r.previous.net);
    final days = r.days;
    final (changeText, changeColor, changeIcon) = change == null
        ? (t.reportPreviousNone(days), theme.colorScheme.outline, Icons.remove)
        : change > 0
            ? (t.reportChangeUp('$change', days), Colors.green.shade700, Icons.trending_up)
            : change < 0
                ? (t.reportChangeDown('${-change}', days), Colors.red.shade700, Icons.trending_down)
                : (t.reportNoChange(days), theme.colorScheme.outline, Icons.trending_flat);
    final adjustments = double.tryParse(r.totals.adjustments) ?? 0;
    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(value, style: theme.textTheme.titleMedium),
          ]),
        );
    return Card(
      key: const Key('report-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.reportNet, style: theme.textTheme.bodySmall),
          Text(rs(r.totals.net),
              key: const Key('report-net'),
              style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary)),
          Row(children: [
            Icon(changeIcon, size: 18, color: changeColor),
            const SizedBox(width: 4),
            Flexible(child: Text(changeText, key: const Key('report-change'), style: TextStyle(color: changeColor))),
          ]),
          if (adjustments != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.reportRefundShares(rs('${adjustments.abs()}')), style: theme.textTheme.bodySmall),
            ),
          const Divider(height: 24),
          Row(children: [
            stat(t.reportJobs, '${r.totals.jobs}'),
            stat(t.reportAverage, rs(r.averagePerJob)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            stat(t.customersPaid, rs(r.totals.gross)),
            stat(t.kaamnowCommission, rs(r.totals.commission)),
          ]),
        ]),
      ),
    );
  }
}

/// A simple bar per day, week or month. Tapping a bar shows its amount.
class EarningsBars extends StatefulWidget {
  const EarningsBars({super.key, required this.report});
  final EarningsReport report;
  @override
  State<EarningsBars> createState() => _EarningsBarsState();
}

class _EarningsBarsState extends State<EarningsBars> {
  int? _selected;

  String _label(ReportBucket b) {
    final lang = strings.localeName;
    return switch (widget.report.group) {
      'month' => DateFormat('MMM yyyy', lang).format(b.start),
      'week' => context.t.weekOf(DateFormat('d MMM', lang).format(b.start)),
      _ => DateFormat('EEE d MMM', lang).format(b.start),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = widget.report.series;
    final values = [for (final b in series) double.tryParse(b.net) ?? 0];
    final top = values.fold<double>(0, (a, b) => b > a ? b : a);
    final best = values.indexOf(top);
    final shown = _selected ?? best;
    final b = series.isEmpty ? null : series[shown.clamp(0, series.length - 1)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (b != null)
        Text('${_label(b)}: ${rs(b.net)} · ${context.t.reportJobsCount(b.jobs)}',
            key: const Key('bar-detail'), style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      SizedBox(
        height: 140,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < series.length; i++)
            Expanded(
              child: GestureDetector(
                key: Key('bar-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selected = i),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: series.length > 40 ? 0.5 : 2),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: top == 0 ? 2 : 2 + 136 * values[i] / top,
                      decoration: BoxDecoration(
                        color: i == shown ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      if (series.isNotEmpty)
        Row(children: [
          Text(_label(series.first), style: theme.textTheme.bodySmall),
          const Spacer(),
          if (series.length > 1) Text(_label(series.last), style: theme.textTheme.bodySmall),
        ]),
    ]);
  }
}

/// Rows with a bar showing each one's share of [total].
class _Shares extends StatelessWidget {
  const _Shares({required this.rows, required this.total});
  final List<(String, int, String)> rows;
  final String total;

  @override
  Widget build(BuildContext context) {
    final all = double.tryParse(total) ?? 0;
    return Column(children: [
      for (final (name, jobs, net) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name)),
              Text(context.t.reportJobsCount(jobs), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              Text(rs(net), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: all <= 0 ? 0 : ((double.tryParse(net) ?? 0) / all).clamp(0, 1)),
          ]),
        ),
    ]);
  }
}
