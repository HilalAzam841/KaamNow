import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/admin_api.dart';
import '../../core/file_opener.dart';
import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

const docLabels = {'cnic_front': 'CNIC front', 'cnic_back': 'CNIC back', 'certificate': 'Certificate', 'other': 'Other'};

/// Workers waiting for verification, oldest first.
class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});
  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  final _list = GlobalKey<PagedListState<AdminWorker>>();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final api = adminApi(context);
    return AdminPage(
      title: 'Worker verification',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone or CNIC', isDense: true),
            onSubmitted: (v) {
              _search = v.trim();
              _list.currentState?.reload();
            },
          ),
        ),
        Expanded(
          child: PagedList<AdminWorker>(
            key: _list,
            empty: 'No workers waiting for verification',
            load: (page) => api.pendingWorkers(search: _search, page: page),
            itemBuilder: (context, w, reload) => Card(
              child: ListTile(
                key: Key('pending-${w.profile.id}'),
                leading: Avatar(name: w.profile.fullName, url: w.profile.profilePicture),
                title: Text(w.profile.fullName),
                subtitle: Text('${w.profile.phone} · CNIC ${w.profile.cnicNumber}\n'
                    '${w.profile.services.map((s) => s.categoryName).join(', ').ifEmpty('No services yet')} · signed up ${ago(w.createdAt)}'),
                isThreeLine: true,
                trailing: w.hasBothCnicSides
                    ? const Chip(label: Text('Ready to review'))
                    : const Chip(label: Text('CNIC incomplete')),
                onTap: () async {
                  await context.push('/admin/workers/${w.profile.id}');
                  reload();
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// One worker's application: profile, services, location and private documents.
class AdminWorkerReviewScreen extends StatefulWidget {
  const AdminWorkerReviewScreen({super.key, required this.id});
  final int id;
  @override
  State<AdminWorkerReviewScreen> createState() => _AdminWorkerReviewScreenState();
}

class _AdminWorkerReviewScreenState extends State<AdminWorkerReviewScreen> {
  late final AdminApi api = adminApi(context);
  final _loader = GlobalKey<LoaderState<AdminWorker>>();

  void _back() => context.canPop() ? context.pop() : context.go('/admin/workers');

  Future<void> _verify(AdminWorker w) async {
    if (!w.hasBothCnicSides &&
        !await confirm(context, 'CNIC is incomplete', 'Both CNIC sides are not uploaded. Verify anyway?', ok: 'Verify')) {
      return;
    }
    if (!mounted) return;
    final r = await runAction(context, () => api.verifyWorker(w.profile.id), success: '${w.profile.fullName} is verified.');
    if (r != null && mounted) _back();
  }

  Future<void> _reject(AdminWorker w) async {
    final reason = await promptText(context, 'Reject ${w.profile.fullName}?',
        label: 'Reason (the worker sees this)', ok: 'Reject', required: true);
    if (reason == null || !mounted) return;
    final r = await runAction(context, () => api.rejectWorker(w.profile.id, reason), success: 'Application rejected.');
    if (r != null && mounted) _back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review worker')),
      body: Loader<AdminWorker>(
        key: _loader,
        load: () => api.worker(widget.id),
        builder: (context, w, reload) {
          final p = w.profile;
          final theme = Theme.of(context);
          return PageBody(
            maxWidth: 980,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Avatar(name: p.fullName, url: p.profilePicture, radius: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.fullName, style: theme.textTheme.headlineSmall),
                    Text('${p.phone}${w.email != null ? ' · ${w.email}' : ''}'),
                    Text('CNIC ${p.cnicNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
                StatusChip(p.verificationStatus, label: humanize(p.verificationStatus)),
              ]),
              if (p.rejectionReason.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('Previously rejected: ${p.rejectionReason}')),
              const SectionTitle('Documents'),
              if (w.documents.isEmpty) const Text('No documents uploaded.'),
              Wrap(spacing: 12, runSpacing: 12, children: [for (final d in w.documents) _DocumentTile(api: api, doc: d)]),
              const SizedBox(height: 4),
              Text('Opening a document is recorded in the audit log.', style: theme.textTheme.bodySmall),
              const SectionTitle('Services'),
              if (p.services.isEmpty) const Text('No services added.'),
              for (final s in p.services)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.categoryName),
                  subtitle: s.description.isEmpty ? null : Text(s.description),
                  trailing: s.startingPrice == null ? null : Text('from ${rs(s.startingPrice)}'),
                ),
              const SectionTitle('Profile'),
              Text(p.bio.isEmpty ? 'No bio.' : p.bio),
              const SizedBox(height: 6),
              Text('${p.experienceYears} years experience · covers ${p.serviceArea.ifEmpty('—')} · radius ${p.serviceRadiusKm} km'),
              if (p.baseLatitude != null) ...[
                const SizedBox(height: 10),
                KaamMap(
                  height: 200,
                  center: LatLng(p.baseLatitude!, p.baseLongitude!),
                  pins: [MapPin(LatLng(p.baseLatitude!, p.baseLongitude!), icon: Icons.location_pin, color: Colors.red)],
                ),
              ] else
                const Text('Base location not set yet.'),
              const SizedBox(height: 24),
              if (p.verificationStatus != 'verified')
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const Key('verify-worker'),
                    onPressed: () => _verify(w),
                    icon: const Icon(Icons.verified),
                    label: const Text('Verify worker'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('reject-worker'),
                    onPressed: () => _reject(w),
                    icon: const Icon(Icons.block),
                    label: const Text('Reject'),
                  ),
                ]),
              const SizedBox(height: 32),
            ]),
          );
        },
      ),
    );
  }
}

/// Loads a private document with the admin's token and previews it; PDFs open in a new tab.
class _DocumentTile extends StatefulWidget {
  const _DocumentTile({required this.api, required this.doc});
  final AdminApi api;
  final AdminDocument doc;
  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  Uint8List? _bytes;
  String? _type;
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await runAction(context, () => widget.api.documentFile(widget.doc.id));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r != null) {
        _bytes = r.$1;
        _type = r.$2;
      }
    });
    if (r != null && !(_type ?? '').startsWith('image/')) {
      if (!openBytes(r.$1, r.$2)) showInfo(context, 'Cannot preview this file here.');
    }
  }

  void _zoom() => showDialog<void>(
        context: context,
        builder: (c) => Dialog(child: InteractiveViewer(child: Image.memory(_bytes!))),
      );

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final isImage = (_type ?? '').startsWith('image/');
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(docLabels[d.type] ?? humanize(d.type), style: Theme.of(context).textTheme.titleSmall)),
              StatusChip(d.status),
            ]),
            Text('${d.filename} · ${day(d.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (_bytes != null && isImage)
              GestureDetector(
                onTap: _zoom,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_bytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
              )
            else
              OutlinedButton.icon(
                key: Key('view-doc-${d.id}'),
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.visibility),
                label: Text(_bytes != null ? 'Open again' : 'View document'),
              ),
          ]),
        ),
      ),
    );
  }
}
