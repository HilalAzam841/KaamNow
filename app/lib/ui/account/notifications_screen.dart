import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

/// Where a notification should take the user, or null.
String? notificationTarget(AppNotification n, {required bool isWorker}) {
  final d = n.data;
  final booking = d['booking_id'];
  final request = d['request_id'];
  if (booking != null) return '/bookings/$booking';
  if (request != null) return isWorker ? '/jobs/$request' : '/requests/$request';
  if (n.type == 'verification' && isWorker) return '/worker/profile';
  if (n.type == 'subscription' && isWorker) return '/worker/plans';
  if (n.type == 'complaint') return '/complaints';
  return null;
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final isWorker = session.user?.isWorker == true;
    final key = GlobalKey<LoaderState<Paged<AppNotification>>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts'), actions: [
        TextButton(
          onPressed: () async {
            await runAction(context, session.api.markAllNotificationsRead);
            key.currentState?.reload();
          },
          child: const Text('Mark all read'),
        ),
      ]),
      body: Loader<Paged<AppNotification>>(
        key: key,
        load: session.api.notifications,
        builder: (context, page, reload) {
          if (page.results.isEmpty) {
            return const EmptyView(icon: Icons.notifications_none, title: 'No alerts yet');
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: PageBody(
              child: ListView.separated(
                itemCount: page.results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = page.results[i];
                  return ListTile(
                    leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: n.isRead ? null : Theme.of(context).colorScheme.primary),
                    title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text('${n.body}\n${ago(n.createdAt)}'),
                    isThreeLine: true,
                    onTap: () async {
                      if (!n.isRead) session.api.markNotificationRead(n.id).catchError((_) {});
                      final target = notificationTarget(n, isWorker: isWorker);
                      if (target != null) await context.push(target);
                      reload();
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
