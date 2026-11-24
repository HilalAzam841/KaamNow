import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/requests/new'),
        tooltip: 'Post a job',
        child: const Icon(Icons.add),
      ),
      body: Loader<Paged<ServiceRequest>>(
        load: () => api.requests(),
        builder: (context, page, reload) {
          if (page.results.isEmpty) {
            return EmptyView(
              icon: Icons.assignment_outlined,
              title: 'No requests yet',
              subtitle: 'Post a job to get prices from nearby workers.',
              action: FilledButton(onPressed: () => context.push('/requests/new'), child: const Text('Post a job')),
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: PageBody(
              child: ListView(padding: const EdgeInsets.all(12), children: [
                for (final r in page.results)
                  Card(
                    child: ListTile(
                      title: Text(r.title),
                      subtitle: Text('${r.categoryName} · ${when(r.preferredTime)}\n'
                          '${r.offersCount} offer${r.offersCount == 1 ? '' : 's'}'),
                      isThreeLine: true,
                      leading: r.isEmergency ? const Icon(Icons.bolt, color: Colors.red) : const Icon(Icons.assignment),
                      trailing: StatusChip(r.status),
                      onTap: () async {
                        await context.push(r.bookingId != null ? '/bookings/${r.bookingId}' : '/requests/${r.id}');
                        reload();
                      },
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
