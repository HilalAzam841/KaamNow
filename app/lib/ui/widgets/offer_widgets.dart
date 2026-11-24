import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import 'common.dart';

const _actionLabels = {
  'offer': 'offered',
  'revise': 'revised the price to',
  'counter': 'countered with',
  'agree': 'agreed to',
  'accept': 'accepted at',
  'reject': 'rejected',
  'withdraw': 'withdrew',
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
                    text: (n.party == 'customer') == viewerIsCustomer ? 'You' : (n.party == 'customer' ? 'Customer' : offer.worker.fullName.split(' ').first),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' ${_actionLabels[n.action] ?? n.action}'),
                if (n.amount != null) TextSpan(text: ' ${rs(n.amount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
      title: const Text('Counter offer'),
      content: Form(
        key: key,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current price: ${rs(current)}'),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('counter-amount'),
            controller: amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Your price', prefixText: 'Rs '),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a price';
              if (n == double.tryParse(current)) return 'That is the current price. Accept instead.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(
          key: const Key('counter-send'),
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(c, (amount.text.trim(), note.text.trim()));
          },
          child: const Text('Send'),
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
                Tooltip(message: 'Verified by KaamNow', child: Icon(Icons.verified, size: 18, color: theme.colorScheme.primary)),
              ],
              if (worker.planBadge.isNotEmpty) ...[
                const SizedBox(width: 6),
                StatusChip('badge', label: worker.planBadge),
              ],
            ]),
            const SizedBox(height: 2),
            Wrap(spacing: 12, children: [
              RatingLine(rating: worker.averageRating, count: worker.ratingCount),
              Text('${worker.completedJobs} job${worker.completedJobs == 1 ? '' : 's'}'),
              Text('${worker.experienceYears} yrs exp'),
            ]),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}
