import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

const auditActions = [
  ('worker_verified', 'Worker verified'),
  ('worker_rejected', 'Worker rejected'),
  ('document_viewed', 'Document viewed'),
  ('user_suspended', 'User suspended'),
  ('user_reactivated', 'User reactivated'),
  ('commission_changed', 'Commission changed'),
  ('settings_changed', 'Settings changed'),
  ('plan_changed', 'Plan changed'),
  ('subscription_activated', 'Subscription activated'),
  ('featured_cancelled', 'Featured cancelled'),
  ('complaint_updated', 'Complaint updated'),
  ('category_changed', 'Category changed'),
  ('payment_disputed', 'Payment disputed'),
];

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});
  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  String? _action;
  final _list = GlobalKey<PagedListState<AuditEntry>>();

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Audit log',
        body: Column(children: [
          FilterChips(
            options: [(null, 'All'), ...auditActions],
            selected: _action,
            onSelected: (v) {
              setState(() => _action = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<AuditEntry>(
              key: _list,
              empty: 'No audit entries',
              load: (page) => adminApi(context).auditLog(action: _action, page: page),
              itemBuilder: (context, a, _) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${humanize(a.action)} · ${a.targetType} #${a.targetId}'),
                  subtitle: Text([
                    '${a.actorName.isEmpty ? 'System' : a.actorName} · ${when(a.createdAt)}',
                    if (a.ip != null) a.ip!,
                    if (a.metadata.isNotEmpty) a.metadata.entries.map((e) => '${humanize(e.key)}: ${e.value}').join(', '),
                  ].join('\n')),
                  isThreeLine: a.metadata.isNotEmpty,
                ),
              ),
            ),
          ),
        ]),
      );
}
