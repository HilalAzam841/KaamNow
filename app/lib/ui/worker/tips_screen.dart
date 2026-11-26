import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';

/// Tips customers gave the worker: the total, then each tip with its note.
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(t.myTips), actions: const [LanguageButton()]),
      body: PageBody(
        child: Loader<(({int count, String total}), List<TipInfo>)>(
          load: () async => (await api.tipSummary(), await api.tips()),
          builder: (context, data, reload) {
            final (summary, tips) = data;
            final theme = Theme.of(context);
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  child: ListTile(
                    key: const Key('tips-total'),
                    leading: const Icon(Icons.volunteer_activism, color: Colors.green),
                    title: Text(rs(summary.total), style: theme.textTheme.headlineSmall),
                    subtitle: Text(t.tipsTotal('${summary.count}', rs(summary.total))),
                  ),
                ),
                const SizedBox(height: 8),
                if (tips.isEmpty)
                  EmptyView(icon: Icons.volunteer_activism_outlined, title: t.noTips)
                else
                  for (final tip in tips)
                    Card(
                      child: ListTile(
                        key: Key('tip-${tip.id}'),
                        title: Text('${rs(tip.amount)} · ${tip.customerName}'),
                        subtitle: Text([
                          tip.bookingTitle,
                          if (tip.message.isNotEmpty) '“${tip.message}”',
                          when(tip.paidAt ?? tip.createdAt),
                        ].join('\n')),
                        isThreeLine: tip.message.isNotEmpty,
                        trailing: Text(switch (tip.status) {
                          'paid' => t.tipStatusPaid,
                          'cancelled' => t.tipStatusCancelled,
                          _ => t.tipStatusPending,
                        }),
                        onTap: tip.bookingId == null ? null : () => context.push('/bookings/${tip.bookingId}'),
                      ),
                    ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
