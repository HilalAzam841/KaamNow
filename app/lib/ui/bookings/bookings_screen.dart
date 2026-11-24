import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _filter = 'active';

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final isWorker = session.user?.isWorker == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'active', label: Text('Active')),
              ButtonSegment(value: 'completed', label: Text('Completed')),
              ButtonSegment(value: 'cancelled', label: Text('Cancelled')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        Expanded(
          child: Loader<Paged<Booking>>(
            key: ValueKey(_filter),
            load: () async {
              if (_filter != 'active') return session.api.bookings(status: _filter);
              final all = await session.api.bookings();
              return Paged(results: all.results.where((b) => b.isActive).toList(), count: all.count);
            },
            builder: (context, page, reload) {
              if (page.results.isEmpty) {
                return EmptyView(
                  icon: Icons.event_busy,
                  title: 'No ${_filter == 'active' ? 'active ' : '$_filter '}bookings',
                  subtitle: _filter == 'active'
                      ? (isWorker ? 'When a customer accepts your offer, the job appears here.'
                          : 'Accept an offer on one of your requests to book a worker.')
                      : null,
                );
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: PageBody(
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    for (final b in page.results)
                      Card(
                        child: ListTile(
                          key: Key('booking-${b.id}'),
                          leading: const Icon(Icons.event_available),
                          title: Text(b.title),
                          subtitle: Text('${isWorker ? b.customerName : b.worker.fullName} · ${rs(b.totalAmount)}\n'
                              '${b.categoryName} · ${when(b.preferredTime)}'),
                          isThreeLine: true,
                          trailing: StatusChip(b.status),
                          onTap: () async {
                            await context.push('/bookings/${b.id}');
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
