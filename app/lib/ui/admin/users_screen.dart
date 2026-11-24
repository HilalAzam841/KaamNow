import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _list = GlobalKey<PagedListState<AdminUser>>();
  String? _filter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final api = adminApi(context);
    return AdminPage(
      title: 'Users',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            key: const Key('user-search'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone or email', isDense: true),
            onSubmitted: (v) {
              _search = v.trim();
              _list.currentState?.reload();
            },
          ),
        ),
        FilterChips(
          options: const [(null, 'All'), ('customer', 'Customers'), ('worker', 'Workers'), ('admin', 'Admins'), ('suspended', 'Suspended')],
          selected: _filter,
          onSelected: (v) {
            setState(() => _filter = v);
            _list.currentState?.reload();
          },
        ),
        Expanded(
          child: PagedList<AdminUser>(
            key: _list,
            empty: 'No users match',
            load: (page) => api.users(
              role: _filter == 'suspended' ? null : _filter,
              suspended: _filter == 'suspended' ? true : null,
              search: _search,
              page: page,
            ),
            itemBuilder: (context, u, reload) => Card(
              child: ListTile(
                key: Key('user-${u.id}'),
                leading: Avatar(name: u.fullName),
                title: Text(u.fullName),
                subtitle: Text('${humanize(u.role)} · ${u.phone}${u.email != null ? ' · ${u.email}' : ''}\n'
                    'Joined ${day(u.dateJoined)}${u.lastLogin != null ? ' · last seen ${ago(u.lastLogin)}' : ''}'
                    '${u.isSuspended ? '\nSuspended: ${u.suspendedReason}' : ''}'),
                isThreeLine: true,
                trailing: u.role == 'admin'
                    ? null
                    : u.isSuspended
                        ? OutlinedButton(
                            onPressed: () async {
                              await runAction(context, () => api.reactivateUser(u.id), success: '${u.fullName} reactivated.');
                              reload();
                            },
                            child: const Text('Reactivate'),
                          )
                        : TextButton(
                            key: Key('suspend-${u.id}'),
                            onPressed: () async {
                              final reason = await promptText(context, 'Suspend ${u.fullName}?',
                                  label: 'Reason', ok: 'Suspend', required: true);
                              if (reason == null || !context.mounted) return;
                              await runAction(context, () => api.suspendUser(u.id, reason),
                                  success: '${u.fullName} suspended and signed out everywhere.');
                              reload();
                            },
                            child: const Text('Suspend'),
                          ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
