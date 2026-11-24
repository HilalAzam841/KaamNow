import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});
  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
  String? _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('My offers')),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            for (final s in const [('pending', 'Pending'), ('accepted', 'Accepted'), (null, 'All')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.$2),
                  selected: _status == s.$1,
                  onSelected: (_) => setState(() => _status = s.$1),
                ),
              ),
          ]),
        ),
        Expanded(
          child: Loader<Paged<WorkerOffer>>(
            key: ValueKey(_status),
            load: () => api.myOffers(status: _status),
            builder: (context, page, reload) {
              if (page.results.isEmpty) {
                return const EmptyView(icon: Icons.local_offer_outlined, title: 'No offers here',
                    subtitle: 'Offers you send on jobs appear here.');
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: PageBody(
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    for (final o in page.results)
                      Card(
                        child: ListTile(
                          title: Text('Job #${o.requestId} · ${rs(o.currentPrice)}'),
                          subtitle: Text(o.isPending
                              ? (o.awaiting == 'worker' ? 'Customer countered. Your move.' : 'Waiting for customer')
                              : 'Sent ${ago(o.createdAt)}'),
                          leading: o.isPending && o.awaiting == 'worker'
                              ? const Icon(Icons.priority_high, color: Colors.orange)
                              : const Icon(Icons.local_offer),
                          trailing: StatusChip(o.status),
                          onTap: () async {
                            await context.push(o.bookingId != null ? '/bookings/${o.bookingId}' : '/jobs/${o.requestId}');
                            reload();
                          },
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
