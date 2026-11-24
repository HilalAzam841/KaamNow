import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import 'common.dart';
import '../../l10n/l10n.dart';

String _negotiationLine(AppLocalizations t, String action, String who, String amount) => switch (action) {
      'offer' => t.negOffer(who, amount),
      'revise' => t.negRevise(who, amount),
      'counter' => t.negCounter(who, amount),
      'agree' => t.negAgree(who, amount),
      'accept' => t.negAccept(who, amount),
      'reject' => t.negReject(who),
      'withdraw' => t.negWithdraw(who),
      _ => '$who $action $amount',
    };

/// Price history of one offer, oldest first.
class NegotiationHistory extends StatelessWidget {
  const NegotiationHistory({super.key, required this.offer, required this.viewerIsCustomer});
  final WorkerOffer offer;
  final bool viewerIsCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final n in offer.negotiations)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(n.party == 'customer' ? Icons.person : Icons.handyman, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                  text: _negotiationLine(
                    context.t,
                    n.action,
                    (n.party == 'customer') == viewerIsCustomer
                        ? context.t.you
                        : (n.party == 'customer' ? context.t.customer : offer.worker.fullName.split(' ').first),
                    n.amount == null ? '' : rs(n.amount),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (n.message.isNotEmpty) TextSpan(text: ': "${n.message}"'),
              ])),
            ),
            Text(ago(n.createdAt), style: theme.textTheme.bodySmall),
          ]),
        ),
    ]);
  }
}

/// Ask for a counter price (and optional note). Returns (amount, message) or null.
Future<(String, String)?> askCounter(BuildContext context, String current) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  final key = GlobalKey<FormState>();
  return showDialog<(String, String)>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(context.t.counterOffer),
      content: Form(
        key: key,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.t.currentPrice(rs(current))),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('counter-amount'),
            controller: amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.t.yourPrice, prefixText: context.t.rsPrefix),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return context.t.enterPrice;
              if (n == double.tryParse(current)) return context.t.samePriceAcceptInstead;
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: InputDecoration(labelText: context.t.noteOptional)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(context.t.cancel)),
        FilledButton(
          key: const Key('counter-send'),
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(c, (amount.text.trim(), note.text.trim()));
          },
          child: Text(context.t.send),
        ),
      ],
    ),
  );
}

class WorkerSummary extends StatelessWidget {
  const WorkerSummary({super.key, required this.worker, this.onTap, this.trailing});
  final PublicWorker worker;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Avatar(name: worker.fullName, url: worker.profilePicture),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(worker.fullName, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
              if (worker.isVerified) ...[
                const SizedBox(width: 4),
                Tooltip(message: context.t.verifiedByKaamnow, child: Icon(Icons.verified, size: 18, color: theme.colorScheme.primary)),
              ],
              if (worker.planBadge.isNotEmpty) ...[
                const SizedBox(width: 6),
                StatusChip('badge', label: worker.planBadge),
              ],
            ]),
            const SizedBox(height: 2),
            Wrap(spacing: 12, children: [
              RatingLine(rating: worker.averageRating, count: worker.ratingCount),
              Text(context.t.jobsCount(worker.completedJobs)),
              Text(context.t.yearsExp(worker.experienceYears)),
            ]),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}
