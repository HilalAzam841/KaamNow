import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

const noShowReviews = [('open', 'Not reviewed'), ('confirmed', 'Confirmed'), ('dismissed', 'Dismissed')];

/// No-show reports: who did not turn up, how often that person has, and the admin's review.
class AdminNoShowsScreen extends StatefulWidget {
  const AdminNoShowsScreen({super.key});
  @override
  State<AdminNoShowsScreen> createState() => _AdminNoShowsScreenState();
}

class _AdminNoShowsScreenState extends State<AdminNoShowsScreen> {
  String? _review = 'open';
  final _list = GlobalKey<PagedListState<AdminNoShow>>();

  Future<void> _review_(AdminNoShow n, VoidCallback reload) async {
    final note = TextEditingController(text: n.adminNote);
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Booking #${n.bookingId}: ${n.bookingTitle}'),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${n.reportedByName} reported that ${n.againstName} (${n.againstRole}) did not show up'
                '${n.preferredTime != null ? ' for ${when(n.preferredTime)}' : ''}.'),
            if (n.note.isNotEmpty) ...[const SizedBox(height: 8), Text('"${n.note}"')],
            const SizedBox(height: 8),
            Text('${n.againstName} has ${n.againstTotal} no-show report(s) that were not dismissed.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('no-show-note'),
              controller: note,
              decoration: const InputDecoration(labelText: 'Admin note (only admins see it)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
          OutlinedButton(
              key: const Key('no-show-dismiss'), onPressed: () => Navigator.pop(d, 'dismissed'), child: const Text('Dismiss')),
          FilledButton(
              key: const Key('no-show-confirm'), onPressed: () => Navigator.pop(d, 'confirmed'), child: const Text('Confirm')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).reviewNoShow(n.id, choice, note: note.text.trim()),
        success: 'Report ${choice == 'confirmed' ? 'confirmed' : 'dismissed'}.');
    if (r != null) reload();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'No-shows',
        body: Column(children: [
          FilterChips(
            options: [for (final s in noShowReviews) (s.$1, s.$2), (null, 'All')],
            selected: _review,
            onSelected: (v) {
              setState(() => _review = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<AdminNoShow>(
              key: _list,
              empty: 'No no-show reports',
              load: (page) => adminApi(context).noShows(review: _review, page: page),
              itemBuilder: (context, n, reload) => Card(
                child: ListTile(
                  key: Key('no-show-${n.id}'),
                  leading: Icon(n.side == 'worker' ? Icons.engineering : Icons.person),
                  title: Text('${n.againstName} · ${n.side == 'worker' ? 'worker did not come' : 'customer not there'}'),
                  subtitle: Text('Booking #${n.bookingId} · reported by ${n.reportedByName} · ${when(n.createdAt)}'
                      '\n${n.againstTotal} report(s) in total'),
                  isThreeLine: true,
                  trailing: StatusChip(n.review == 'open' ? 'pending' : n.review == 'confirmed' ? 'verified' : 'rejected',
                      label: noShowReviews.firstWhere((r) => r.$1 == n.review, orElse: () => (n.review, n.review)).$2),
                  onTap: () => _review_(n, reload),
                ),
              ),
            ),
          ),
        ]),
      );
}
