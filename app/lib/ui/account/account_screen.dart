import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../core/session.dart';
import '../../core/format.dart';
import '../widgets/common.dart';
import '../widgets/install_widgets.dart';
import '../widgets/push_widgets.dart';
import '../widgets/language_button.dart';
import '../../l10n/l10n.dart';

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
        title: Text(context.t.editProfile),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: context.t.fullName)),
          const SizedBox(height: 12),
          TextField(controller: email, decoration: InputDecoration(labelText: context.t.email)),
          if (u.isCustomer) ...[
            const SizedBox(height: 12),
            TextField(controller: address, decoration: InputDecoration(labelText: context.t.defaultAddress)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.t.save)),
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
    }, success: context.t.profileUpdated);
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.t.changePassword),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: current, obscureText: true, decoration: InputDecoration(labelText: context.t.currentPassword)),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: InputDecoration(labelText: context.t.newPassword)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.t.change)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runAction(context, () => context.read<Session>().api.changePassword(current.text, next.text),
        success: context.t.passwordChangedShort);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final u = session.user;
    if (u == null) return const SizedBox();
    return Scaffold(
      appBar: AppBar(title: Text(context.t.tabAccount), actions: const [LanguageButton()]),
      body: PageBody(
        child: ListView(children: [
          ListTile(
            leading: Avatar(name: u.fullName, url: u.avatar),
            title: Text(u.fullName),
            subtitle: Text('${ltr(u.phone)}${u.email != null ? '\n${ltr(u.email!)}' : ''}'),
            isThreeLine: u.email != null,
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editProfile(context)),
          ),
          const Divider(),
          if (u.isWorker) ...[
            ListTile(
              leading: const Icon(Icons.badge),
              title: Text(context.t.workerProfileServicesDocs),
              onTap: () => context.push('/worker/profile'),
            ),
            ListTile(leading: const Icon(Icons.payments), title: Text(context.t.earnings), onTap: () => context.push('/worker/earnings')),
            ListTile(leading: const Icon(Icons.workspace_premium), title: Text(context.t.plans), onTap: () => context.push('/worker/plans')),
          ],
          const PushTile(),
          const InstallTile(),
          ListTile(leading: const Icon(Icons.support_agent), title: Text(context.t.helpAndComplaints), onTap: () => context.push('/complaints')),
          ListTile(leading: const Icon(Icons.lock), title: Text(context.t.changePassword), onTap: () => _changePassword(context)),
          ListTile(
            key: const Key('logout'),
            leading: const Icon(Icons.logout),
            title: Text(context.t.logOut),
            onTap: () => session.logout(),
          ),
          const Divider(),
          if (session.config.supportEmail.isNotEmpty)
            ListTile(dense: true, leading: const Icon(Icons.mail_outline), title: Text(context.t.supportEmail(session.config.supportEmail))),
          ListTile(dense: true, title: Text(context.t.appVersion(AppConfig.appVersion))),
        ]),
      ),
    );
  }
}
