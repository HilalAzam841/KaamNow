import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

const _reasons = {'late': 'Cancelled late', 'on_the_way': 'Worker on the way', 'arrived': 'Worker had arrived'};

/// Late cancellation fees. Waive one, or record one paid at the office; both are audited.
class AdminCancellationFeesScreen extends StatefulWidget {
  const AdminCancellationFeesScreen({super.key});
  @override
  State<AdminCancellationFeesScreen> createState() => _AdminCancellationFeesScreenState();
}

class _AdminCancellationFeesScreenState extends State<AdminCancellationFeesScreen> {
  String? _status = 'owed';
  final _list = GlobalKey<PagedListState<AdminCancellationFee>>();

  Future<void> _waive(AdminCancellationFee f, VoidCallback reload) async {
    final reason = await promptText(context, 'Waive this fee?',
        label: 'Reason (recorded in the audit log)', ok: 'Waive', required: true);
    if (reason == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).waiveCancellationFee(f.id, reason.trim()),
        success: 'Fee waived. The customer was told.');
    if (r != null) reload();
  }

  Future<void> _received(AdminCancellationFee f, VoidCallback reload) async {
    final ref = await promptText(context, 'Record ${rs(f.amount)} as received?',
        label: 'Receipt or transfer reference (optional)', ok: 'Record');
    if (ref == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).recordCancellationFee(f.id, ref.trim()),
        success: "Recorded. The worker's share was added to their wallet.");
    if (r != null) reload();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Cancellation fees',
        body: Column(children: [
          FilterChips(
            options: const [('owed', 'Owed'), ('paid', 'Paid'), ('waived', 'Waived'), (null, 'All')],
            selected: _status,
            onSelected: (v) {
              setState(() => _status = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<AdminCancellationFee>(
              key: _list,
              empty: 'No fees',
              load: (page) => adminApi(context).cancellationFees(status: _status, page: page),
              itemBuilder: (context, f, reload) => Card(
                child: ListTile(
                  key: Key('admin-fee-${f.id}'),
                  title: Text('${rs(f.amount)} · ${f.customerName} · booking #${f.bookingId}'),
                  subtitle: Text([
                    _reasons[f.reason] ?? f.reason,
                    'Worker ${f.workerName} gets ${rs(f.workerShare)}',
                    if (f.createdAt != null) when(f.createdAt),
                    f.status == 'waived' ? 'Waived: ${f.waivedReason}' : f.status,
                  ].join(' · ')),
                  trailing: f.status != 'owed'
                      ? null
                      : Wrap(spacing: 4, children: [
                          TextButton(
                            key: Key('admin-fee-received-${f.id}'),
                            onPressed: () => _received(f, reload),
                            child: const Text('Received'),
                          ),
                          TextButton(
                            key: Key('admin-fee-waive-${f.id}'),
                            onPressed: () => _waive(f, reload),
                            child: const Text('Waive'),
                          ),
                        ]),
                ),
              ),
            ),
          ),
        ]),
      );
}
