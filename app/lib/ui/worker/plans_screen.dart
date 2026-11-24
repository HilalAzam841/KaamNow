import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/checkout_launcher.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../../l10n/l10n.dart';

/// Subscription plans: lower commission and more daily offers.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final api = session.api;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t.plans), actions: const [LanguageButton()]),
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
                  title: Text(context.t.currentPlan(mine.plan.name)),
                  subtitle: Text([
                    context.t.commissionPercent(mine.commissionPercent),
                    mine.offersRemaining == null ? context.t.unlimitedOffers : context.t.offersLeftToday(mine.offersRemaining!),
                    if (mine.endsAt != null) context.t.renewsOrEnds(day(mine.endsAt)),
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
                        Text((double.tryParse(p.price) ?? 0) == 0 ? context.t.free : context.t.pricePerDays(rs(p.price), p.durationDays),
                            style: theme.textTheme.titleMedium),
                      ]),
                      if (p.description.isNotEmpty) Text(p.description),
                      const SizedBox(height: 6),
                      Text('${p.commissionPercent == null ? context.t.commissionStandard : context.t.commissionPercent(p.commissionPercent!)} · '
                          '${p.dailyOfferLimit == null ? context.t.unlimitedOffers : context.t.offersADay(p.dailyOfferLimit!)}'),
                      for (final b in p.benefits) Text('• $b'),
                      const SizedBox(height: 10),
                      if (p.id == mine.plan.id)
                        StatusChip('active', label: context.t.yourPlan)
                      else if ((double.tryParse(p.price) ?? 0) == 0)
                        OutlinedButton(
                          onPressed: () async {
                            await runAction(context, () => api.subscribe(p.id), success: context.t.switchedTo(p.name));
                            reload();
                          },
                          child: Text(context.t.switchToPlan),
                        )
                      else if (online.isEmpty)
                        Text(context.t.onlinePaymentSoon)
                      else
                        Wrap(spacing: 8, children: [
                          for (final m in online)
                            FilledButton(
                              onPressed: () async {
                                final checkout = await runAction(context, () => api.subscribe(p.id, method: m.code));
                                if (checkout != null && context.mounted) {
                                  final outcome = await openCheckout(context, checkout);
                                  if (!context.mounted) return;
                                  showInfo(context, switch (outcome) {
                                    CheckoutOutcome.openedInNewTab => context.t.finishPayingNewTab,
                                    CheckoutOutcome.returned => context.t.planPaymentWindowClosed,
                                    CheckoutOutcome.failed => context.t.onlinePaymentUnavailable,
                                  });
                                }
                              },
                              child: Text(context.t.payWith(m.label)),
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
