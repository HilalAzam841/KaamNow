import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../../l10n/l10n.dart';

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
      appBar: AppBar(title: Text(context.t.tabMyOffers)),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            for (final s in [('pending', context.t.statusPending), ('accepted', context.t.statusAccepted), (null, context.t.all)])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
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
                return EmptyView(icon: Icons.local_offer_outlined, title: context.t.noOffersHere,
                    subtitle: context.t.noOffersHereHint);
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: PageBody(
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    for (final o in page.results)
                      Card(
                        child: ListTile(
                          title: Text(context.t.jobNumberPrice(o.requestId, rs(o.currentPrice))),
                          subtitle: Text(o.isPending
                              ? (o.awaiting == 'worker' ? context.t.customerCounteredShort : context.t.waitingForCustomerShort)
                              : context.t.sentAgo(ago(o.createdAt))),
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
