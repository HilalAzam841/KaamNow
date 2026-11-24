import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

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
      appBar: AppBar(title: const Text('Earnings')),
      body: Loader<EarningsSummary>(
        load: api.earnings,
        builder: (context, e, reload) => RefreshIndicator(
          onRefresh: reload,
          child: PageBody(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                stat('You earned', rs(e.net), color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                stat('Completed jobs', '${e.completedJobs}'),
              ]),
              Row(children: [
                stat('Customers paid', rs(e.gross)),
                const SizedBox(width: 8),
                stat('KaamNow commission', rs(e.commission)),
              ]),
              if ((double.tryParse(e.commissionPending) ?? 0) > 0)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text('Commission due: ${rs(e.commissionPending)}'),
                    subtitle: const Text('From cash jobs. KaamNow will contact you about settling it.'),
                  ),
                ),
              Text('Your current commission rate is ${e.commissionPercent}%.', style: theme.textTheme.bodySmall),
              const SectionTitle('Recent jobs'),
              if (e.recent.isEmpty) const Text('No completed jobs yet.'),
              for (final c in e.recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Booking #${c.bookingId} · ${rs(c.gross)}'),
                  subtitle: Text('${c.ratePercent}% commission ${rs(c.commission)} · ${day(c.createdAt)}'),
                  trailing: Text(rs(c.earning), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
