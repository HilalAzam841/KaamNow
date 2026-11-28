import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// Work guarantee claims. Claims the customer sent to the team are handled under Complaints.
class AdminGuaranteeScreen extends StatefulWidget {
  const AdminGuaranteeScreen({super.key});
  @override
  State<AdminGuaranteeScreen> createState() => _AdminGuaranteeScreenState();
}

class _AdminGuaranteeScreenState extends State<AdminGuaranteeScreen> {
  String? _status;
  final _list = GlobalKey<PagedListState<GuaranteeClaim>>();

  static const _labels = {
    'pending': 'Waiting for worker',
    'accepted': 'Worker coming back',
    'declined': 'Declined',
    'redo_done': 'Worker says fixed',
    'fixed': 'Fixed',
    'escalated': 'Sent to team',
    'withdrawn': 'Withdrawn',
  };

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Guarantee claims',
        body: Column(children: [
          FilterChips(
            options: const [
              (null, 'All'),
              ('pending', 'Waiting'),
              ('declined', 'Declined'),
              ('escalated', 'Sent to team'),
              ('fixed', 'Fixed'),
            ],
            selected: _status,
            onSelected: (v) {
              setState(() => _status = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<GuaranteeClaim>(
              key: _list,
              empty: 'No guarantee claims',
              load: (page) => adminApi(context).guaranteeClaims(status: _status, page: page),
              itemBuilder: (context, c, reload) => Card(
                child: ListTile(
                  key: Key('admin-claim-${c.id}'),
                  title: Text('${c.bookingTitle} · ${c.customerName} → ${c.workerName}'),
                  subtitle: Text([
                    'Booking #${c.bookingId}',
                    _labels[c.status] ?? c.status,
                    if (c.createdAt != null) when(c.createdAt),
                    '“${c.problem}”',
                    if (c.workerNote.isNotEmpty) 'Worker: ${c.workerNote}',
                    if (c.complaintId != null) 'Complaint #${c.complaintId}',
                  ].join(' · ')),
                ),
              ),
            ),
          ),
        ]),
      );
}
