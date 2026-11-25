import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

const sosStatuses = [('open', 'Open'), ('acknowledged', 'Someone is on it'), ('resolved', 'Resolved')];

/// SOS alerts raised during jobs. Open ones need a call straight away.
class AdminSosScreen extends StatefulWidget {
  const AdminSosScreen({super.key});
  @override
  State<AdminSosScreen> createState() => _AdminSosScreenState();
}

class _AdminSosScreenState extends State<AdminSosScreen> {
  String? _status = 'open';
  final _list = GlobalKey<PagedListState<AdminSosAlert>>();

  Widget _phone(String label, String name, String phone) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text('$label: $name'),
        subtitle: SelectableText(phone),
        trailing: IconButton(
          tooltip: 'Copy number',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
        ),
      );

  Future<void> _open(AdminSosAlert a, VoidCallback reload) async {
    final note = TextEditingController(text: a.adminNote);
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('SOS on booking #${a.bookingId}: ${a.bookingTitle}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Raised by the ${a.role} ${ago(a.createdAt)}. Booking is ${a.bookingStatus.replaceAll('_', ' ')}.'),
              if (a.note.isNotEmpty) ...[const SizedBox(height: 8), Text('"${a.note}"')],
              const SizedBox(height: 8),
              _phone('Raised by (${a.role})', a.raisedByName, a.raisedByPhone),
              _phone('Other side (${a.otherRole})', a.otherName, a.otherPhone),
              Text('Address: ${a.address}'),
              if (a.latitude != null) SelectableText('Position when raised: ${a.latitude}, ${a.longitude}'),
              Text('${a.contactsTexted} emergency contact(s) were texted.'),
              if (a.handledByName != null) Text('Handled by ${a.handledByName}.'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sos-admin-note'),
                controller: note,
                decoration: const InputDecoration(labelText: 'What was done (only admins see it)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
          if (a.status == 'open')
            OutlinedButton(
                key: const Key('sos-acknowledge'),
                onPressed: () => Navigator.pop(d, 'acknowledged'),
                child: const Text("I'm on it")),
          if (a.status != 'resolved')
            FilledButton(
                key: const Key('sos-resolve'), onPressed: () => Navigator.pop(d, 'resolved'), child: const Text('Resolved')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).handleSos(a.id, choice, note: note.text.trim()),
        success: choice == 'resolved' ? 'Alert resolved.' : 'Marked as being handled. The person was told.');
    if (r != null) reload();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'SOS alerts',
        body: Column(children: [
          FilterChips(
            options: [for (final s in sosStatuses) (s.$1, s.$2), (null, 'All')],
            selected: _status,
            onSelected: (v) {
              setState(() => _status = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<AdminSosAlert>(
              key: _list,
              empty: 'No SOS alerts',
              load: (page) => adminApi(context).sosAlerts(status: _status, page: page),
              itemBuilder: (context, a, reload) => Card(
                color: a.status == 'open' ? Colors.red.shade50 : null,
                child: ListTile(
                  key: Key('sos-${a.id}'),
                  leading: Icon(Icons.sos, color: a.status == 'open' ? Colors.red : null),
                  title: Text('${a.raisedByName} (${a.role}) · ${a.raisedByPhone}'),
                  subtitle: Text('Booking #${a.bookingId} · ${a.bookingTitle} · ${when(a.createdAt)}'),
                  trailing: StatusChip(
                      a.status == 'open' ? 'failed' : a.status == 'acknowledged' ? 'pending' : 'resolved',
                      label: sosStatuses.firstWhere((s) => s.$1 == a.status, orElse: () => (a.status, a.status)).$2),
                  onTap: () => _open(a, reload),
                ),
              ),
            ),
          ),
        ]),
      );
}
