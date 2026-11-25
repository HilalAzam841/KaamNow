import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/checkout_launcher.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

String payoutMethodLabel(BuildContext context, String method) => switch (method) {
  'jazzcash' => 'JazzCash',
  'easypaisa' => 'Easypaisa',
  'bank' => context.t.bankTransfer,
  _ => humanize(method),
};

/// The worker's balance with KaamNow: ask for a payout when KaamNow owes them, pay the commission
/// when they owe KaamNow.
class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.wallet, required this.onChanged});
  final Wallet wallet;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final w = wallet;
    final balance = w.balanceValue;
    final open = w.openSettlement;
    final (headline, color) = balance > 0
        ? (t.walletOwedToYou, theme.colorScheme.primary)
        : balance < 0
        ? (t.walletYouOwe, theme.colorScheme.error)
        : (t.walletSettled, theme.colorScheme.onSurface);
    return Card(
      key: const Key('wallet-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.walletBalance, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(headline, style: theme.textTheme.titleMedium)),
                Text(
                  rs(balance.abs().toStringAsFixed(2)),
                  key: const Key('wallet-balance'),
                  style: theme.textTheme.headlineSmall?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.walletEarningsHeld(rs(w.earningsHeld)), style: theme.textTheme.bodyMedium),
            Text(t.walletCommissionOwed(rs(w.commissionOwed)), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(t.walletExplain, style: theme.textTheme.bodySmall),
            if (w.offersBlocked) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('wallet-offers-blocked'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.offersBlockedDebt(rs(w.commissionDebtLimit)),
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (open != null)
              _OpenSettlement(settlement: open, onChanged: onChanged)
            else if (balance > 0)
              w.canRequestPayout
                  ? FilledButton.icon(
                      key: const Key('wallet-get-paid'),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: Text(t.getPaid),
                      onPressed: () => _requestPayout(context),
                    )
                  : Text(t.minPayoutHint(rs(w.minPayout)), style: theme.textTheme.bodySmall)
            else if (balance < 0)
              _PayCommission(onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPayout(BuildContext context) async {
    final account = await showDialog<PayoutAccount>(
      context: context,
      builder: (_) => _PayoutDialog(amount: wallet.balance, last: wallet.lastPayoutAccount),
    );
    if (account == null || !context.mounted) return;
    final api = context.read<Session>().api;
    final r = await runAction(context, () => api.requestPayout(account), success: context.t.payoutRequested);
    if (r != null) await onChanged();
  }
}

class _OpenSettlement extends StatelessWidget {
  const _OpenSettlement({required this.settlement, required this.onChanged});
  final Settlement settlement;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = settlement;
    return Container(
      key: const Key('wallet-open-settlement'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.isPayout ? t.payoutOpen(rs(s.amount)) : t.commissionPaymentOpen(rs(s.amount)),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (s.isPayout) ...[
            const SizedBox(height: 4),
            Text(t.payoutOpenHint(payoutMethodLabel(context, s.method), s.accountNumber)),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('wallet-cancel-payout'),
              onPressed: () async {
                final api = context.read<Session>().api;
                final r = await runAction(context, () => api.cancelPayout(s.id), success: t.payoutCancelled);
                if (r != null) await onChanged();
              },
              child: Text(t.cancelPayout),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayCommission extends StatelessWidget {
  const _PayCommission({required this.onChanged});
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final session = context.read<Session>();
    final online = session.config.paymentMethods.where((m) => m.code != 'cash' && m.available).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (online.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in online)
                FilledButton(
                  key: Key('wallet-pay-${m.code}'),
                  onPressed: () async {
                    final checkout = await runAction(context, () => session.api.payCommission(m.code));
                    if (checkout == null || !context.mounted) return;
                    final outcome = await openCheckout(context, checkout);
                    if (!context.mounted) return;
                    showInfo(context, switch (outcome) {
                      CheckoutOutcome.openedInNewTab => t.finishPayingNewTab,
                      CheckoutOutcome.returned => t.commissionPaymentWindowClosed,
                      CheckoutOutcome.failed => t.onlinePaymentUnavailable,
                    });
                    await onChanged();
                  },
                  child: Text(t.payWith(m.label)),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Text(t.payCommissionOffice, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PayoutDialog extends StatefulWidget {
  const _PayoutDialog({required this.amount, this.last});
  final String amount;
  final PayoutAccount? last;
  @override
  State<_PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends State<_PayoutDialog> {
  final _form = GlobalKey<FormState>();
  late String _method = widget.last?.method ?? 'jazzcash';
  late final _title = TextEditingController(text: widget.last?.accountTitle ?? '');
  late final _number = TextEditingController(text: widget.last?.accountNumber ?? '');

  @override
  void dispose() {
    _title.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    String? required(String? v) => (v ?? '').trim().isEmpty ? t.requiredField : null;
    return AlertDialog(
      title: Text(t.getPaid),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('payout-method'),
                  initialValue: _method,
                  decoration: InputDecoration(labelText: t.payoutTo),
                  items: [
                    for (final m in ['jazzcash', 'easypaisa', 'bank'])
                      DropdownMenuItem(value: m, child: Text(payoutMethodLabel(context, m))),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('payout-title'),
                  controller: _title,
                  decoration: InputDecoration(labelText: t.accountTitle),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('payout-number'),
                  controller: _number,
                  decoration: InputDecoration(
                    labelText: _method == 'bank' ? t.iban : t.walletNumber,
                    hintText: _method == 'bank' ? 'PK36SCBL0000001123456702' : '03001234567',
                  ),
                  keyboardType: _method == 'bank' ? TextInputType.text : TextInputType.phone,
                  validator: required,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
          key: const Key('payout-submit'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              PayoutAccount(method: _method, accountTitle: _title.text.trim(), accountNumber: _number.text.trim()),
            );
          },
          child: Text(t.requestPayoutOf(rs(widget.amount))),
        ),
      ],
    );
  }
}

/// Past payouts and commission payments.
class SettlementHistory extends StatelessWidget {
  const SettlementHistory({super.key, required this.settlements});
  final List<Settlement> settlements;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (settlements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(t.settlementHistory),
        for (final s in settlements)
          ListTile(
            key: Key('settlement-${s.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text('${s.isPayout ? t.settlementPayout : t.settlementCollection} · ${rs(s.amount)}'),
            subtitle: Text(
              [
                t.settlementLine(day(s.createdAt), payoutMethodLabel(context, s.method)),
                if (s.reference.isNotEmpty) s.reference,
                if (s.note.isNotEmpty) s.note,
              ].join('\n'),
            ),
            trailing: StatusChip(s.status),
          ),
      ],
    );
  }
}
