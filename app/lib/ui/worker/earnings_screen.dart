import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../../l10n/l10n.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    final theme = Theme.of(context);
    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(color: color)),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(context.t.earnings)),
      body: Loader<EarningsSummary>(
        load: api.earnings,
        builder: (context, e, reload) => RefreshIndicator(
          onRefresh: reload,
          child: PageBody(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                stat(context.t.youEarned, rs(e.net), color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                stat(context.t.completedJobs, '${e.completedJobs}'),
              ]),
              Row(children: [
                stat(context.t.customersPaid, rs(e.gross)),
                const SizedBox(width: 8),
                stat(context.t.kaamnowCommission, rs(e.commission)),
              ]),
              if ((double.tryParse(e.commissionPending) ?? 0) > 0)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(context.t.commissionDue(rs(e.commissionPending))),
                    subtitle: Text(context.t.commissionDueHint),
                  ),
                ),
              Text(context.t.commissionRateNow(e.commissionPercent), style: theme.textTheme.bodySmall),
              SectionTitle(context.t.recentJobs),
              if (e.recent.isEmpty) Text(context.t.noCompletedJobs),
              for (final c in e.recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t.bookingNumberPrice(c.bookingId, rs(c.gross))),
                  subtitle: Text(context.t.commissionLine(c.ratePercent, rs(c.commission), day(c.createdAt))),
                  trailing: Text(rs(c.earning), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
