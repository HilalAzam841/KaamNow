import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/checkout_launcher.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

/// Subscription plans: lower commission and more daily offers.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final api = session.api;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: Loader<(MySubscription, List<SubscriptionPlan>)>(
        load: () async => (await api.mySubscription(), await api.subscriptionPlans()),
        builder: (context, data, reload) {
          final (mine, plans) = data;
          final online = session.config.paymentMethods.where((m) => m.code != 'cash' && m.available).toList();
          return PageBody(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  title: Text('Current plan: ${mine.plan.name}'),
                  subtitle: Text([
                    'Commission ${mine.commissionPercent}%',
                    mine.offersRemaining == null ? 'Unlimited offers' : '${mine.offersRemaining} offers left today',
                    if (mine.endsAt != null) 'Renews or ends ${day(mine.endsAt)}',
                  ].join(' · ')),
                ),
              ),
              for (final p in plans)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(p.name, style: theme.textTheme.titleLarge)),
                        Text((double.tryParse(p.price) ?? 0) == 0 ? 'Free' : '${rs(p.price)} / ${p.durationDays} days',
                            style: theme.textTheme.titleMedium),
                      ]),
                      if (p.description.isNotEmpty) Text(p.description),
                      const SizedBox(height: 6),
                      Text('Commission ${p.commissionPercent ?? 'standard'}${p.commissionPercent != null ? '%' : ''} · '
                          '${p.dailyOfferLimit == null ? 'Unlimited offers' : '${p.dailyOfferLimit} offers a day'}'),
                      for (final b in p.benefits) Text('• $b'),
                      const SizedBox(height: 10),
                      if (p.id == mine.plan.id)
                        const StatusChip('active', label: 'Your plan')
                      else if ((double.tryParse(p.price) ?? 0) == 0)
                        OutlinedButton(
                          onPressed: () async {
                            await runAction(context, () => api.subscribe(p.id), success: 'Switched to ${p.name}.');
                            reload();
                          },
                          child: const Text('Switch to this plan'),
                        )
                      else if (online.isEmpty)
                        const Text('Online payment is coming soon. Contact KaamNow support to upgrade.')
                      else
                        Wrap(spacing: 8, children: [
                          for (final m in online)
                            FilledButton(
                              onPressed: () async {
                                final checkout = await runAction(context, () => api.subscribe(p.id, method: m.code));
                                if (checkout != null && context.mounted) {
                                  openCheckout(checkout)
                                      ? showInfo(context, 'Finish paying in the new tab. Your plan activates once it is confirmed.')
                                      : showInfo(context, 'Online payment is not available on this device yet.');
                                }
                              },
                              child: Text('Pay with ${m.label}'),
                            ),
                        ]),
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
