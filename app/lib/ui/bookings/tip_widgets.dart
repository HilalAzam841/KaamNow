import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/checkout_launcher.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

/// What the customer chose in the tip dialog.
typedef TipChoice = ({String amount, String method, String message});

/// The tip section on a completed booking: a button for the customer, a status line for both
/// sides, and "I got it" / "Not received" for a worker's pending cash tip.
class TipPanel extends StatelessWidget {
  const TipPanel({super.key, required this.booking, required this.isWorker, required this.onChanged});
  final Booking booking;
  final bool isWorker;
  final VoidCallback onChanged;

  Future<void> _give(BuildContext context) async {
    final session = context.read<Session>();
    final choice = await showDialog<TipChoice>(
      context: context,
      builder: (_) => TipDialog(
        workerName: booking.worker.fullName.split(' ').first,
        settings: session.config.tips,
        onlineMethods: [
          for (final m in session.config.paymentMethods)
            if (m.code != 'cash' && m.available) m.code
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final r = await runAction(context,
        () => session.api.giveTip(booking.id, amount: choice.amount, method: choice.method, message: choice.message));
    if (r == null || !context.mounted) return;
    final checkout = r.$2;
    if (checkout == null) {
      showInfo(context, context.t.tipCashSent);
    } else {
      final outcome = await openCheckout(context, checkout);
      if (!context.mounted) return;
      showInfo(context, switch (outcome) {
        CheckoutOutcome.openedInNewTab => context.t.completePaymentNewTab,
        CheckoutOutcome.returned => context.t.paymentWindowClosed,
        CheckoutOutcome.failed => context.t.onlinePaymentUnavailable,
      });
    }
    onChanged();
  }

  Future<void> _confirm(BuildContext context, TipInfo tip) async {
    final api = context.read<Session>().api;
    final r = await runAction(context, () => api.confirmCashTip(tip.id), success: context.t.tipConfirmed);
    if (r != null) onChanged();
  }

  Future<void> _decline(BuildContext context, TipInfo tip) async {
    final t = context.t;
    if (!await confirm(context, t.tipNotReceivedQ, t.tipNotReceivedBody, ok: t.tipNotReceived)) return;
    if (!context.mounted) return;
    final api = context.read<Session>().api;
    final r = await runAction(context, () => api.cashTipNotReceived(tip.id), success: t.tipCancelled);
    if (r != null) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final tip = booking.tip;
    final children = <Widget>[];
    if (tip != null) {
      final String text;
      if (isWorker) {
        text = tip.isPaid
            ? t.tipWorkerPaid(rs(tip.amount))
            : (tip.isCash ? t.tipWorkerPending(rs(tip.amount)) : t.tipWorkerPendingOnline(rs(tip.amount)));
      } else {
        text = tip.isPaid
            ? t.tipPaidCustomer(rs(tip.amount))
            : (tip.isCash ? t.tipPendingCash(rs(tip.amount)) : t.tipPendingOnline(rs(tip.amount)));
      }
      children.add(Row(children: [
        Icon(Icons.volunteer_activism, color: tip.isPaid ? Colors.green : theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, key: const Key('tip-status'))),
      ]));
      if (tip.message.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsetsDirectional.only(start: 28, top: 4),
          child: Text('“${tip.message}”', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        ));
      }
      if (isWorker && tip.isPending && tip.isCash) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(key: const Key('tip-got-it'), onPressed: () => _confirm(context, tip), child: Text(t.tipGotIt)),
            OutlinedButton(
                key: const Key('tip-not-received'),
                onPressed: () => _decline(context, tip),
                child: Text(t.tipNotReceived)),
          ]),
        ));
      }
    }
    if (!isWorker && booking.canTip) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FilledButton.tonalIcon(
          key: const Key('give-tip'),
          onPressed: () => _give(context),
          icon: const Icon(Icons.volunteer_activism),
          label: Text(tip == null ? t.tipWorker(booking.worker.fullName.split(' ').first) : t.tipChange),
        ),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Picks an amount (a suggestion or a custom one), how to pay, and an optional note.
class TipDialog extends StatefulWidget {
  const TipDialog({super.key, required this.workerName, required this.settings, required this.onlineMethods});
  final String workerName;
  final TipSettings settings;
  final List<String> onlineMethods;
  @override
  State<TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<TipDialog> {
  final _form = GlobalKey<FormState>();
  late String? _picked = widget.settings.suggestions.isEmpty ? null : widget.settings.suggestions.first;
  final _other = TextEditingController();
  final _message = TextEditingController();
  String _method = 'cash';

  @override
  void dispose() {
    _other.dispose();
    _message.dispose();
    super.dispose();
  }

  String get _amount => _picked ?? _other.text.trim();

  String? _validate(String? v) {
    if (_picked != null) return null;
    final n = double.tryParse((v ?? '').trim());
    final min = double.tryParse(widget.settings.min) ?? 50;
    final max = double.tryParse(widget.settings.max) ?? 5000;
    if (n == null || n < min || n > max) return context.t.tipRange(rs(widget.settings.min), rs(widget.settings.max));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      title: Text(t.tipTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.tipHint(widget.workerName)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in widget.settings.suggestions)
                ChoiceChip(
                  key: Key('tip-amount-$s'),
                  label: Text(rs(s)),
                  selected: _picked == s,
                  onSelected: (_) => setState(() => _picked = s),
                ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('tip-other'),
              controller: _other,
              decoration: InputDecoration(labelText: t.tipOther),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => _picked = v.trim().isEmpty && widget.settings.suggestions.isNotEmpty
                  ? widget.settings.suggestions.first
                  : null),
              validator: _validate,
            ),
            const SizedBox(height: 16),
            Text(t.tipHow, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in ['cash', ...widget.onlineMethods])
                ChoiceChip(
                  key: Key('tip-method-$m'),
                  label: Text(m == 'cash' ? t.tipCashOption : paymentMethodLabel(m)),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ]),
            const SizedBox(height: 8),
            TextField(
              key: const Key('tip-message'),
              controller: _message,
              maxLength: 200,
              decoration: InputDecoration(labelText: t.tipMessage),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
          key: const Key('tip-send'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop<TipChoice>(context, (amount: _amount, method: _method, message: _message.text.trim()));
          },
          child: Text(t.tipSend),
        ),
      ],
    );
  }
}
