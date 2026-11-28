import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../bookings/job_photos.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// All bookings and requests across the platform.
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});
  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  bool _bookings = true;
  String? _status;
  String _search = '';
  final _bookingList = GlobalKey<PagedListState<Booking>>();
  final _requestList = GlobalKey<PagedListState<ServiceRequest>>();

  void _reload() => _bookings ? _bookingList.currentState?.reload() : _requestList.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final api = adminApi(context);
    final statuses = _bookings
        ? const [(null, 'All'), ('confirmed', 'Confirmed'), ('on_the_way', 'On the way'), ('in_progress', 'In progress'),
            ('completed', 'Completed'), ('cancelled', 'Cancelled')]
        : const [(null, 'All'), ('open', 'Open'), ('booked', 'Booked'), ('cancelled', 'Cancelled'), ('expired', 'Expired')];
    return AdminPage(
      title: 'Jobs',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Bookings')), ButtonSegment(value: false, label: Text('Requests'))],
              selected: {_bookings},
              onSelectionChanged: (s) => setState(() {
                _bookings = s.first;
                _status = null;
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search', isDense: true),
                onSubmitted: (v) {
                  _search = v.trim();
                  _reload();
                },
              ),
            ),
          ]),
        ),
        FilterChips(options: statuses, selected: _status, onSelected: (v) {
          setState(() => _status = v);
          WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
        }),
        Expanded(
          child: _bookings
              ? PagedList<Booking>(
                  key: _bookingList,
                  empty: 'No bookings',
                  load: (page) => api.bookings(status: _status, search: _search, page: page),
                  itemBuilder: (context, b, _) => Card(
                    child: ListTile(
                      title: Text('#${b.id} · ${b.title}'),
                      subtitle: Text('${b.customerName} → ${b.worker.fullName} · ${b.categoryName}\n'
                          '${rs(b.totalAmount)}${(double.tryParse(b.emergencyFee) ?? 0) > 0 ? ' (incl. ${rs(b.emergencyFee)} emergency)' : ''} · ${when(b.createdAt)}'
                          '${b.cancelReason.isNotEmpty ? '\nCancelled: ${b.cancelReason}' : ''}'),
                      isThreeLine: true,
                      trailing: StatusChip(b.status),
                      onTap: () => _showTimeline(context, b),
                    ),
                  ),
                )
              : PagedList<ServiceRequest>(
                  key: _requestList,
                  empty: 'No requests',
                  load: (page) => api.requests(status: _status, search: _search, page: page),
                  itemBuilder: (context, r, _) => Card(
                    child: ListTile(
                      leading: r.isEmergency ? const Icon(Icons.bolt, color: Colors.red) : const Icon(Icons.assignment),
                      title: Text('#${r.id} · ${r.title}'),
                      subtitle: Text('${r.categoryName} · ${r.area.isEmpty ? r.address : r.area} · ${r.offersCount} offers\n'
                          'Posted ${when(r.createdAt)} for ${when(r.preferredTime)}'),
                      isThreeLine: true,
                      trailing: StatusChip(r.status),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  void _showTimeline(BuildContext context, Booking b) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Booking #${b.id}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b.title} · ${b.categoryName}'),
              Text('Customer: ${b.customerName}'),
              Text('Worker: ${b.worker.fullName}'),
              Text('Agreed ${rs(b.agreedPrice)} · total ${rs(b.totalAmount)}'),
              const Divider(),
              for (final l in b.statusHistory)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${when(l.createdAt)} · ${bookingStatusLabel(l.toStatus)}${l.note.isNotEmpty ? ' (${l.note})' : ''}'),
                ),
              // Before and after photos, for disputes. Opening one is recorded in the audit log.
              if (b.jobPhotos.total > 0)
                JobPhotosSection(
                  key: const Key('admin-job-photos'),
                  load: () async => (b.jobPhotos, await adminApi(c).bookingPhotos(b.id)),
                  loadBytes: adminApi(c).jobPhotoBytes,
                ),
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );
}
