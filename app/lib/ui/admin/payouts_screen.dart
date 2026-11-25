import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

String _method(String m) => switch (m) {
  'jazzcash' => 'JazzCash',
  'easypaisa' => 'Easypaisa',
  'bank' => 'Bank transfer',
  'cash' => 'Cash',
  _ => humanize(m),
};

/// Settling money with workers: send requested payouts, and record commission handed in by
/// workers who were paid in cash.
class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});
  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  String? _view = 'requests';
  final _list = GlobalKey<PagedListState<Settlement>>();
  int _owingVersion = 0;

  Future<String?> _ask(String title, String message, String label, String ok, {Key? fieldKey}) async {
    final field = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                key: fieldKey,
                controller: field,
                decoration: InputDecoration(labelText: label),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
          FilledButton(
            key: const Key('dialog-ok'),
            onPressed: () {
              if (field.text.trim().isNotEmpty) Navigator.pop(d, field.text.trim());
            },
            child: Text(ok),
          ),
        ],
      ),
    );
    return r;
  }

  Future<void> _markPaid(Settlement s, VoidCallback reload) async {
    final ref = await _ask(
      'Mark payout paid',
      'First send ${rs(s.amount)} to ${s.accountTitle}, ${_method(s.method)} ${s.accountNumber}. '
          'Then enter the transaction ID. The worker is told, and this is recorded in the audit log.',
      'Transaction ID',
      'Mark paid',
      fieldKey: const Key('payout-reference'),
    );
    if (ref == null || !mounted) return;
    final r = await runAction(
      context,
      () => adminApi(context).markPayoutPaid(s.id, ref),
      success: 'Payout marked paid.',
    );
    if (r != null) reload();
  }

  Future<void> _reject(Settlement s, VoidCallback reload) async {
    final reason = await _ask(
      'Decline payout',
      'The balance goes back to the worker\'s wallet. Tell them why.',
      'Reason (shown to the worker)',
      'Decline',
      fieldKey: const Key('payout-reason'),
    );
    if (reason == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).rejectPayout(s.id, reason), success: 'Payout declined.');
    if (r != null) reload();
  }

  Future<void> _record(WorkerBalance b) async {
    var method = 'cash';
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text('Commission from ${b.workerName}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record that ${b.workerName} paid ${rs(b.balance.replaceFirst('-', ''))}, the commission they owe. '
                  'Recorded in the audit log.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('commission-method'),
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash at the office')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                  ],
                  onChanged: (v) => setState(() => method = v ?? method),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('commission-reference'),
                  controller: ref,
                  decoration: const InputDecoration(labelText: 'Receipt number or transaction ID'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Close')),
            FilledButton(
              key: const Key('dialog-ok'),
              onPressed: () {
                if (ref.text.trim().isNotEmpty) Navigator.pop(d, true);
              },
              child: const Text('Record payment'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runAction(
      context,
      () => adminApi(context).recordCommission(b.workerId, method, ref.text.trim()),
      success: 'Commission recorded.',
    );
    if (r != null) setState(() => _owingVersion++);
  }

  Widget _settlementTile(Settlement s, VoidCallback reload) {
    final open = s.isOpen && s.isPayout;
    return Card(
      key: Key('settlement-${s.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${s.workerName} · ${rs(s.amount)}', style: Theme.of(context).textTheme.titleMedium),
                ),
                StatusChip(s.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              s.isPayout
                  ? 'Payout to ${s.accountTitle}, ${_method(s.method)} ${s.accountNumber}'
                  : 'Commission paid by ${_method(s.method)}',
            ),
            Text(
              'Online earnings ${rs(s.earningsAmount)} minus cash commission ${rs(s.commissionAmount)} · '
              '${s.bookings.length} bookings · ${s.workerPhone} · ${when(s.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (s.reference.isNotEmpty || s.note.isNotEmpty)
              Text(
                [if (s.reference.isNotEmpty) 'Ref ${s.reference}', if (s.note.isNotEmpty) s.note].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (open) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: Key('mark-paid-${s.id}'),
                    onPressed: () => _markPaid(s, reload),
                    child: const Text('Mark paid'),
                  ),
                  OutlinedButton(
                    key: Key('reject-${s.id}'),
                    onPressed: () => _reject(s, reload),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _owing() => Loader<List<WorkerBalance>>(
    key: ValueKey(_owingVersion),
    load: () => adminApi(context).workerBalances(owing: true),
    builder: (context, rows, reload) => rows.isEmpty
        ? const Center(child: Text('No worker owes commission'))
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final b in rows)
                Card(
                  key: Key('owing-${b.workerId}'),
                  child: ListTile(
                    title: Text('${b.workerName} owes ${rs(b.balance.replaceFirst('-', ''))}'),
                    subtitle: Text(
                      'Cash commission ${rs(b.commissionOwed)} minus online earnings ${rs(b.earningsHeld)}'
                      ' · ${b.workerPhone}',
                    ),
                    trailing: OutlinedButton(
                      key: Key('record-${b.workerId}'),
                      onPressed: () => _record(b),
                      child: const Text('Record payment'),
                    ),
                  ),
                ),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Payouts',
    body: Column(
      children: [
        FilterChips(
          options: const [('requests', 'Payout requests'), ('owing', 'Owe commission'), (null, 'History')],
          selected: _view,
          onSelected: (v) {
            setState(() => _view = v);
            WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
          },
        ),
        Expanded(
          child: _view == 'owing'
              ? _owing()
              : PagedList<Settlement>(
                  key: _list,
                  empty: _view == 'requests' ? 'No payout requests waiting' : 'No payouts yet',
                  load: (page) => adminApi(context).settlements(
                    kind: _view == 'requests' ? 'payout' : null,
                    status: _view == 'requests' ? 'requested' : null,
                    page: page,
                  ),
                  itemBuilder: (context, s, reload) => _settlementTile(s, reload),
                ),
        ),
      ],
    ),
  );
}
