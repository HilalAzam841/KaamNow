import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

String _methodLabel(String m) => switch (m) {
  'jazzcash' => 'JazzCash',
  'easypaisa' => 'Easypaisa',
  'gateway' => 'JazzCash / Easypaisa portal',
  'bank' => 'Bank transfer',
  'cash' => 'Cash',
  _ => humanize(m),
};

const _refundMethods = ['gateway', 'bank', 'cash'];

/// Customer payments: resolve disputed ones and record refunds. KaamNow sends refunds itself
/// (merchant portal, bank or cash); this page records them with their reference.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});
  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  String? _view = 'disputed';
  final _list = GlobalKey<PagedListState<AdminPayment>>();

  Future<void> _refund(AdminPayment p, VoidCallback reload) async {
    final r = await showDialog<_RefundInput>(
      context: context,
      builder: (_) => _RefundDialog(payment: p),
    );
    if (r == null || !mounted) return;
    final done = await runAction(
      context,
      () => adminApi(context).refundPayment(p.id,
          amount: r.amount, method: r.method, reason: r.reason, reference: r.reference, chargeWorker: r.chargeWorker),
      success: 'Refund recorded.',
    );
    if (done != null) reload();
  }

  Future<void> _resolve(AdminPayment p, String resolution, VoidCallback reload) async {
    final r = await showDialog<_RefundInput>(
      context: context,
      builder: (_) => _ResolveDialog(payment: p, resolution: resolution),
    );
    if (r == null || !mounted) return;
    final done = await runAction(
      context,
      () => adminApi(context).resolvePayment(p.id, resolution, r.reason,
          method: resolution == 'refund' ? r.method : null, reference: resolution == 'refund' ? r.reference : null),
      success: switch (resolution) {
        'accept' => 'Payment accepted.',
        'refund' => 'Refund recorded.',
        _ => 'Payment rejected.',
      },
    );
    if (done != null) reload();
  }

  Widget _tile(AdminPayment p, VoidCallback reload) {
    final pay = p.payment;
    final theme = Theme.of(context);
    return Card(
      key: Key('payment-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${p.payerName} · ${rs(pay.amount)} · ${_methodLabel(pay.method)}',
                      style: theme.textTheme.titleMedium),
                ),
                StatusChip(pay.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (pay.bookingId != null) 'Booking #${pay.bookingId}' else humanize(pay.purpose),
                if (p.workerName != null) 'Worker ${p.workerName}',
                p.payerPhone,
                when(pay.createdAt),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              [
                'Ref ${pay.reference}',
                if (p.gatewayTransactionId.isNotEmpty) 'Gateway ${p.gatewayTransactionId}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (pay.failureReason.isNotEmpty)
              Text(pay.failureReason, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            for (final r in p.refunds)
              Text(
                'Refunded ${rs(r.amount)} via ${_methodLabel(r.method)} · Ref ${r.reference} · ${r.reason}'
                '${(double.tryParse(r.workerShare) ?? 0) > 0 ? ' · worker paid ${rs(r.workerShare)}' : ''}',
                key: Key('refund-${r.id}'),
                style: theme.textTheme.bodySmall,
              ),
            if (p.isDisputed || p.canRefund) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.isDisputed) ...[
                    if (pay.purpose == 'booking')
                      FilledButton(
                        key: Key('accept-${p.id}'),
                        onPressed: () => _resolve(p, 'accept', reload),
                        child: const Text('Accept payment'),
                      ),
                    OutlinedButton(
                      key: Key('resolve-refund-${p.id}'),
                      onPressed: () => _resolve(p, 'refund', reload),
                      child: const Text('Refunded'),
                    ),
                    OutlinedButton(
                      key: Key('reject-${p.id}'),
                      onPressed: () => _resolve(p, 'reject', reload),
                      child: const Text('No money arrived'),
                    ),
                  ] else
                    OutlinedButton.icon(
                      key: Key('refund-${p.id}'),
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: () => _refund(p, reload),
                      label: Text('Refund (up to ${rs(p.refundableAmount)})'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Payments',
    body: Column(
      children: [
        FilterChips(
          options: const [('disputed', 'Disputed'), ('completed', 'Completed'), ('refunded', 'Refunded'), (null, 'All')],
          selected: _view,
          onSelected: (v) {
            setState(() => _view = v);
            WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
          },
        ),
        Expanded(
          child: PagedList<AdminPayment>(
            key: _list,
            empty: _view == 'disputed' ? 'No disputed payments' : 'No payments',
            load: (page) => adminApi(context).payments(
              status: _view == 'refunded' ? null : _view,
              refunded: _view == 'refunded' ? true : null,
              page: page,
            ),
            itemBuilder: (context, p, reload) => _tile(p, reload),
          ),
        ),
      ],
    ),
  );
}

class _RefundInput {
  _RefundInput({this.amount = '', this.method = 'gateway', required this.reason, this.reference = '',
      this.chargeWorker = false});
  final String amount;
  final String method;
  final String reason;
  final String reference;
  final bool chargeWorker;
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.payment});
  final AdminPayment payment;
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.payment.refundableAmount);
  final _reason = TextEditingController();
  final _reference = TextEditingController();
  late String _method = widget.payment.payment.method == 'cash' ? 'cash' : 'gateway';
  bool _chargeWorker = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = double.tryParse(widget.payment.refundableAmount) ?? 0;
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    return AlertDialog(
      title: Text('Refund ${widget.payment.payerName}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('First send the money back, then record it here. The customer is told, and this is '
                    'recorded in the audit log.'),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('refund-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount (up to ${rs(widget.payment.refundableAmount)})'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'Enter an amount';
                    if (n > max) return 'At most ${rs(widget.payment.refundableAmount)}';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('refund-method'),
                  isExpanded: true,
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Sent by'),
                  items: [for (final m in _refundMethods) DropdownMenuItem(value: m, child: Text(_methodLabel(m)))],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('refund-reference'),
                  controller: _reference,
                  decoration: const InputDecoration(labelText: 'Refund transaction ID or receipt number'),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('refund-reason'),
                  controller: _reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: required,
                ),
                CheckboxListTile(
                  key: const Key('refund-charge-worker'),
                  contentPadding: EdgeInsets.zero,
                  value: _chargeWorker,
                  onChanged: (v) => setState(() => _chargeWorker = v ?? false),
                  title: const Text('Charge the worker their share'),
                  subtitle: const Text('Takes the worker\'s part of the refund from their wallet. '
                      'Otherwise KaamNow pays it.'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(
          key: const Key('dialog-ok'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              _RefundInput(
                amount: _amount.text.trim(),
                method: _method,
                reason: _reason.text.trim(),
                reference: _reference.text.trim(),
                chargeWorker: _chargeWorker,
              ),
            );
          },
          child: const Text('Record refund'),
        ),
      ],
    );
  }
}

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.payment, required this.resolution});
  final AdminPayment payment;
  final String resolution;
  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _reference = TextEditingController();
  String _method = 'gateway';

  @override
  void dispose() {
    _note.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final refund = widget.resolution == 'refund';
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    final (title, message, ok) = switch (widget.resolution) {
      'accept' => (
        'Accept payment',
        'Only if you found ${rs(p.payment.amount)} from ${p.payerName} in the ${_methodLabel(p.payment.method)} portal. '
            'It then counts as the payment for booking #${p.payment.bookingId}.',
        'Accept',
      ),
      'refund' => (
        'Record refund',
        'First send ${rs(p.payment.amount)} back to ${p.payerName}, then record it here.',
        'Record refund',
      ),
      _ => (
        'No money arrived',
        'Only if the ${_methodLabel(p.payment.method)} portal shows no money for ${p.payment.reference}. '
            'The customer is told to contact support if they were charged.',
        'Reject',
      ),
    };
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              if (refund) ...[
                DropdownButtonFormField<String>(
                  key: const Key('resolve-method'),
                  isExpanded: true,
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Sent by'),
                  items: [for (final m in _refundMethods) DropdownMenuItem(value: m, child: Text(_methodLabel(m)))],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('resolve-reference'),
                  controller: _reference,
                  decoration: const InputDecoration(labelText: 'Refund transaction ID or receipt number'),
                  validator: required,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('resolve-note'),
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note for the audit log'),
                validator: required,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(
          key: const Key('dialog-ok'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context,
                _RefundInput(method: _method, reason: _note.text.trim(), reference: _reference.text.trim()));
          },
          child: Text(ok),
        ),
      ],
    );
  }
}
