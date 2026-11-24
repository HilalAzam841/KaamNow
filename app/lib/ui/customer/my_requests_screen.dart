import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../../l10n/l10n.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.tabMyRequests)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/requests/new'),
        tooltip: context.t.postAJob,
        child: const Icon(Icons.add),
      ),
      body: Loader<Paged<ServiceRequest>>(
        load: () => api.requests(),
        builder: (context, page, reload) {
          if (page.results.isEmpty) {
            return EmptyView(
              icon: Icons.assignment_outlined,
              title: context.t.noRequestsYet,
              subtitle: context.t.noRequestsHint,
              action: FilledButton(onPressed: () => context.push('/requests/new'), child: Text(context.t.postAJob)),
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
                      subtitle: Text('${r.categoryName} · ${when(r.preferredTime)}\n${context.t.offersCount(r.offersCount)}'),
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
