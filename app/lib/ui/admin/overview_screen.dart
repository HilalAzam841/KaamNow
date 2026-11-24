import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = adminApi(context);
    return AdminPage(
      title: 'Overview',
      body: Loader<(Map<String, dynamic>, Map<String, dynamic>, Map<String, dynamic>)>(
        load: () async => (await api.dashboard(), await api.reports(), await api.otherRevenue()),
        builder: (context, data, reload) {
          final (d, r, other) = data;
          final users = asMap(d['users']);
          final workers = asMap(d['workers']);
          final bookings = asMap(d['bookings']);
          final daily = last30Days((r['daily_bookings_last_30_days'] as List? ?? const []).map(asMap));
          final byCategory = (r['bookings_by_category'] as List? ?? const []).map(asMap).toList();
          final top = (r['top_workers'] as List? ?? const []).map(asMap).toList();
          final pending = parseInt(workers['pending']);
          final openComplaints = parseInt(other['open_complaints']);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                StatCard(label: 'Workers waiting for verification', value: '$pending', icon: Icons.verified_user,
                    color: pending > 0 ? Colors.orange.shade800 : null, onTap: () => context.go('/admin/workers')),
                StatCard(label: 'Open complaints', value: '$openComplaints', icon: Icons.support_agent,
                    color: openComplaints > 0 ? Colors.red.shade700 : null, onTap: () => context.go('/admin/complaints')),
                StatCard(label: 'Bookings today', value: '${d['bookings_today'] ?? 0}', icon: Icons.today),
                StatCard(label: 'Gross booking value', value: rsShort(d['gross_booking_value']), icon: Icons.trending_up),
                StatCard(label: 'Commission earned (${d['commission_rate_percent']}%)', value: rsShort(d['total_commission']),
                    icon: Icons.account_balance_wallet, onTap: () => context.go('/admin/revenue')),
                StatCard(label: 'Customers', value: '${users['customer'] ?? 0}', icon: Icons.person),
                StatCard(label: 'Workers (verified / online)',
                    value: '${workers['verified'] ?? 0} / ${workers['online'] ?? 0}', icon: Icons.handyman),
                StatCard(label: 'Suspended users', value: '${d['suspended_users'] ?? 0}', icon: Icons.block),
              ]),
              const SectionTitle('Bookings, last 30 days'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BarChart(points: [
                    for (final p in daily) (str(p['date']).length >= 10 ? str(p['date']).substring(5) : str(p['date']), (parseDouble(p['bookings']) ?? 0)),
                  ]),
                ),
              ),
              const SectionTitle('Bookings by status'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in bookings.entries) Chip(label: Text('${bookingStatusLabel(e.key)}: ${e.value}')),
                Chip(label: Text('Request to booking conversion: ${((parseDouble(r['request_to_booking_conversion']) ?? 0) * 100).toStringAsFixed(0)}%')),
              ]),
              LayoutBuilder(builder: (context, c) {
                final categories = _table(context, 'Bookings by service', ['Service', 'Bookings', 'Completed', 'Avg price'], [
                  for (final row in byCategory)
                    [str(row['category']), '${row['bookings']}', '${row['completed']}', rs(str(row['avg_price']))],
                ]);
                final workersTable = _table(context, 'Top workers', ['Worker', 'Jobs', 'Rating'], [
                  for (final w in top) [str(w['name']), '${w['completed_jobs']}', str(w['average_rating'])],
                ]);
                if (c.maxWidth < 800) return Column(children: [categories, workersTable]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: categories),
                  const SizedBox(width: 16),
                  Expanded(child: workersTable),
                ]);
              }),
            ]),
          );
        },
      ),
    );
  }

  Widget _table(BuildContext context, String title, List<String> headers, List<List<String>> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title),
      Card(
        child: rows.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Text('No data yet'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [for (final h in headers) DataColumn(label: Text(h))],
                  rows: [for (final r in rows) DataRow(cells: [for (final c in r) DataCell(Text(c))])],
                ),
              ),
      ),
    ]);
  }
}

/// The server lists only days that had bookings; fill the gaps so the chart reads as a timeline.
List<Map<String, dynamic>> last30Days(Iterable<Map<String, dynamic>> rows, {DateTime? today}) {
  final counts = {for (final r in rows) '${r['date']}': parseInt(r['bookings'])};
  final end = today ?? DateTime.now();
  return [
    for (var i = 29; i >= 0; i--)
      () {
        final d = DateTime(end.year, end.month, end.day - i);
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return {'date': key, 'bookings': counts[key] ?? 0};
      }(),
  ];
}
