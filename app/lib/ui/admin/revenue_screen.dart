import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});
  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  DateTimeRange? _range;
  String? _commissionStatus;
  final _list = GlobalKey<PagedListState<AdminCommission>>();

  String? get _from => _range == null ? null : _iso(_range!.start);
  String? get _to => _range == null ? null : _iso(_range!.end);
  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
        context: context, firstDate: DateTime(2025), lastDate: now, initialDateRange: _range);
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final api = adminApi(context);
    return AdminPage(
      title: 'Revenue',
      actions: [
        if (_range != null) TextButton(onPressed: () => setState(() => _range = null), child: const Text('All time')),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range),
          label: Text(_range == null ? 'All time' : '${day(_range!.start)} – ${day(_range!.end)}'),
        ),
      ],
      body: Loader<(Map<String, dynamic>, Map<String, dynamic>)>(
        key: ValueKey('$_from$_to'),
        load: () async => (await api.revenue(from: _from, to: _to), await api.otherRevenue(from: _from, to: _to)),
        builder: (context, data, reload) {
          final (r, o) = data;
          final monthly = (r['monthly'] as List? ?? const []).map(asMap).toList();
          final byMethod = asMap(r['payments_by_method']);
          final subs = asMap(o['active_subscriptions']);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatCard(label: 'Completed bookings', value: '${r['completed_bookings'] ?? 0}', icon: Icons.task_alt),
              StatCard(label: 'Gross booking value', value: rsShort(r['gross_booking_value']), icon: Icons.trending_up),
              StatCard(label: 'Commission revenue', value: rsShort(r['commission_revenue']), icon: Icons.account_balance_wallet),
              StatCard(label: 'Worker earnings', value: rsShort(r['worker_earnings']), icon: Icons.handyman),
              StatCard(label: 'Commission collected', value: rsShort(r['commission_collected']), icon: Icons.check_circle),
              StatCard(label: 'Commission due from workers', value: rsShort(r['commission_pending']), icon: Icons.pending,
                  color: (parseDouble(r['commission_pending']) ?? 0) > 0 ? Colors.orange.shade800 : null),
              StatCard(label: 'Subscriptions', value: rsShort(o['subscription_revenue']), icon: Icons.workspace_premium),
              StatCard(label: 'Featured listings', value: rsShort(o['featured_revenue']), icon: Icons.star),
              StatCard(label: 'Emergency fees', value: rsShort(o['emergency_fee_revenue']), icon: Icons.bolt),
            ]),
            const SectionTitle('Monthly commission'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(
                  format: (v) => 'Rs ${v.round()}',
                  points: [for (final m in monthly) (str(m['month']).length >= 7 ? str(m['month']).substring(0, 7) : str(m['month']), parseDouble(m['commission']) ?? 0)],
                ),
              ),
            ),
            const SectionTitle('Payments received'),
            Wrap(spacing: 8, children: [
              Chip(label: Text('Total ${rsShort(r['payments_received'])}')),
              for (final e in byMethod.entries) Chip(label: Text('${humanize(e.key)}: ${rsShort(e.value)}')),
              Chip(label: Text('Active featured listings: ${o['active_featured_listings'] ?? 0}')),
              for (final e in subs.entries) Chip(label: Text('${humanize(e.key)} plan: ${e.value} active')),
            ]),
            SectionTitle('Commissions', trailing: DropdownButton<String?>(
              value: _commissionStatus,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Due')),
                DropdownMenuItem(value: 'collected', child: Text('Collected')),
                DropdownMenuItem(value: 'waived', child: Text('Waived')),
              ],
              onChanged: (v) {
                setState(() => _commissionStatus = v);
                WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
              },
            )),
            SizedBox(
              height: 420,
              child: Card(
                child: PagedList<AdminCommission>(
                  key: _list,
                  empty: 'No commissions',
                  load: (page) => api.commissions(status: _commissionStatus, page: page),
                  itemBuilder: (context, c, _) => ListTile(
                    dense: true,
                    title: Text('Booking #${c.commission.bookingId} · ${c.workerName}'),
                    subtitle: Text('${rs(c.commission.gross)} at ${c.commission.ratePercent}% · ${day(c.commission.createdAt)}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(rs(c.commission.commission), style: const TextStyle(fontWeight: FontWeight.bold)),
                      StatusChip(c.commission.status, label: c.commission.status == 'pending' ? 'Due' : null),
                    ]),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
