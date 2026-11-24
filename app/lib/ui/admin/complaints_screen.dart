import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

const complaintStatuses = [('open', 'Open'), ('in_review', 'In review'), ('resolved', 'Resolved'), ('rejected', 'Rejected')];

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});
  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  String? _status = 'open';
  final _list = GlobalKey<PagedListState<AdminComplaint>>();

  Future<void> _handle(AdminComplaint c, VoidCallback reload) async {
    var status = c.complaint.status;
    final resolution = TextEditingController(text: c.complaint.resolution);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(c.complaint.subject),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${humanize(c.complaint.category)} · raised by ${c.raisedByName} (${c.raisedByRole})'
                    '${c.againstUserName != null ? ' against ${c.againstUserName}' : ''}'
                    '${c.complaint.bookingId != null ? ' · booking #${c.complaint.bookingId}' : ''}'),
                const SizedBox(height: 8),
                Text(c.complaint.description),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('complaint-status'),
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [for (final s in complaintStatuses) DropdownMenuItem(value: s.$1, child: Text(s.$2))],
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('complaint-resolution'),
                  controller: resolution,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Resolution note (shown to the customer)'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Close')),
            FilledButton(key: const Key('save-complaint'), onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runAction(context, () => adminApi(context).updateComplaint(c.complaint.id, status, resolution.text.trim()),
        success: 'Complaint updated.');
    if (r != null) reload();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Complaints',
        body: Column(children: [
          FilterChips(
            options: [for (final s in complaintStatuses) (s.$1, s.$2), (null, 'All')],
            selected: _status,
            onSelected: (v) {
              setState(() => _status = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<AdminComplaint>(
              key: _list,
              empty: 'No complaints',
              load: (page) => adminApi(context).complaints(status: _status, page: page),
              itemBuilder: (context, c, reload) => Card(
                child: ListTile(
                  key: Key('complaint-${c.complaint.id}'),
                  title: Text(c.complaint.subject),
                  subtitle: Text('${humanize(c.complaint.category)} · ${c.raisedByName}'
                      '${c.againstUserName != null ? ' → ${c.againstUserName}' : ''} · ${when(c.complaint.createdAt)}'),
                  trailing: StatusChip(c.complaint.status),
                  onTap: () => _handle(c, reload),
                ),
              ),
            ),
          ),
        ]),
      );
}
