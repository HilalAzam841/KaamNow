import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../core/session.dart';
import '../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _editProfile(BuildContext context) async {
    final session = context.read<Session>();
    final u = session.user!;
    final name = TextEditingController(text: u.fullName);
    final email = TextEditingController(text: u.email ?? '');
    final address = TextEditingController(text: u.defaultAddress);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          if (u.isCustomer) ...[
            const SizedBox(height: 12),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Default address')),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runAction(context, () async {
      await session.api.updateMe({
        'full_name': name.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        if (u.isCustomer) 'default_address': address.text.trim(),
      });
      await session.refreshUser();
    }, success: 'Profile updated.');
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runAction(context, () => context.read<Session>().api.changePassword(current.text, next.text),
        success: 'Password changed.');
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final u = session.user;
    if (u == null) return const SizedBox();
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: PageBody(
        child: ListView(children: [
          ListTile(
            leading: Avatar(name: u.fullName, url: u.avatar),
            title: Text(u.fullName),
            subtitle: Text('${u.phone}${u.email != null ? '\n${u.email}' : ''}'),
            isThreeLine: u.email != null,
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editProfile(context)),
          ),
          const Divider(),
          if (u.isWorker) ...[
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Worker profile, services and documents'),
              onTap: () => context.push('/worker/profile'),
            ),
            ListTile(leading: const Icon(Icons.payments), title: const Text('Earnings'), onTap: () => context.push('/worker/earnings')),
            ListTile(leading: const Icon(Icons.workspace_premium), title: const Text('Plans'), onTap: () => context.push('/worker/plans')),
          ],
          ListTile(leading: const Icon(Icons.support_agent), title: const Text('Help and complaints'), onTap: () => context.push('/complaints')),
          ListTile(leading: const Icon(Icons.lock), title: const Text('Change password'), onTap: () => _changePassword(context)),
          ListTile(
            key: const Key('logout'),
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => session.logout(),
          ),
          const Divider(),
          if (session.config.supportEmail.isNotEmpty)
            ListTile(dense: true, leading: const Icon(Icons.mail_outline), title: Text('Support: ${session.config.supportEmail}')),
          const ListTile(dense: true, title: Text('KaamNow ${AppConfig.appVersion}')),
        ]),
      ),
    );
  }
}

/// Admins manage KaamNow in the admin panel; the customer/worker app is not for them.
class AdminNoticeScreen extends StatelessWidget {
  const AdminNoticeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyView(
          icon: Icons.admin_panel_settings,
          title: 'This app is for customers and workers',
          subtitle: 'Admins use the admin API and the Django admin panel at ${AppConfig.apiBaseUrl}/django-admin/.',
          action: FilledButton(onPressed: () => context.read<Session>().logout(), child: const Text('Log out')),
        ),
      );
}
