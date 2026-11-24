import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/kaamnow_api.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';

const _docTypes = {'cnic_front': 'CNIC front', 'cnic_back': 'CNIC back', 'certificate': 'Certificate', 'other': 'Other'};

/// Everything a worker needs to get verified and win jobs.
class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});
  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  late final KaamNowApi api = context.read<Session>().api;
  WorkerProfile? _p;
  List<WorkerDocument> _docs = [];
  List<ServiceCategory> _categories = [];
  Object? _error;

  final _bio = TextEditingController();
  final _exp = TextEditingController();
  final _area = TextEditingController();
  final _radius = TextEditingController();
  LatLng? _base;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([api.myWorkerProfile(), api.myDocuments(), api.categories()]);
      if (!mounted) return;
      final p = results[0] as WorkerProfile;
      setState(() {
        _p = p;
        _docs = results[1] as List<WorkerDocument>;
        _categories = results[2] as List<ServiceCategory>;
        _bio.text = p.bio;
        _exp.text = '${p.experienceYears}';
        _area.text = p.serviceArea;
        _radius.text = p.serviceRadiusKm;
        _base = p.baseLatitude == null ? null : LatLng(p.baseLatitude!, p.baseLongitude!);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final p = await runAction(
      context,
      () => api.updateWorkerProfile({
        'bio': _bio.text.trim(),
        'experience_years': int.tryParse(_exp.text.trim()) ?? 0,
        'service_area': _area.text.trim(),
        'service_radius_km': _radius.text.trim(),
        if (_base != null) 'base_latitude': _base!.latitude.toStringAsFixed(6),
        if (_base != null) 'base_longitude': _base!.longitude.toStringAsFixed(6),
      }),
      success: 'Profile saved.',
    );
    if (mounted) setState(() => _saving = false);
    if (p != null) _load();
  }

  Future<void> _useMyLocation() async {
    final (fix, error) = await LocationService().current();
    if (!mounted) return;
    if (fix != null) setState(() => _base = LatLng(fix.latitude, fix.longitude));
    if (error != null) showInfo(context, error);
  }

  Future<void> _upload(String type) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (f == null || !mounted) return;
    final file = UploadFile(field: 'file', filename: f.name, bytes: await f.readAsBytes());
    if (!mounted) return;
    await runAction(context, () => api.uploadDocument(type, file), success: '${_docTypes[type]} uploaded.');
    _load();
  }

  Future<void> _uploadPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (f == null || !mounted) return;
    final file = UploadFile(field: 'profile_picture', filename: f.name, bytes: await f.readAsBytes());
    if (!mounted) return;
    await runAction(context, () => api.uploadProfilePicture(file), success: 'Photo updated.');
    _load();
  }

  Future<void> _addService() async {
    final existing = _p!.services.map((s) => s.category).toSet();
    final options = _categories.where((c) => !existing.contains(c.id)).toList();
    if (options.isEmpty) return showInfo(context, 'You already offer every service.');
    final r = await showDialog<(int, String)>(context: context, builder: (_) => _AddServiceDialog(options: options));
    if (r == null || !mounted) return;
    await runAction(context, () => api.addService(r.$1, startingPrice: r.$2), success: 'Service added.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final theme = Theme.of(context);
    final config = context.read<Session>().config;
    return Scaffold(
      appBar: AppBar(title: const Text('My worker profile')),
      body: p == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : PageBody(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Stack(children: [
                    Avatar(name: p.fullName, url: p.profilePicture, radius: 36),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton.filledTonal(
                          iconSize: 16, onPressed: _uploadPhoto, icon: const Icon(Icons.camera_alt), tooltip: 'Change photo'),
                    ),
                  ]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.fullName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      StatusChip(p.verificationStatus, label: humanize(p.verificationStatus)),
                      const SizedBox(height: 4),
                      RatingLine(rating: p.averageRating, count: p.ratingCount),
                    ]),
                  ),
                ]),
                if (p.verificationStatus == 'rejected' && p.rejectionReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Reason: ${p.rejectionReason}', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SectionTitle('Verification documents'),
                Text('CNIC images are private. Only KaamNow staff can see them.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final type in _docTypes.keys)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_docs.any((d) => d.documentType == type) ? Icons.check_circle : Icons.upload_file,
                        color: _docs.any((d) => d.documentType == type) ? Colors.green : null),
                    title: Text(_docTypes[type]!),
                    subtitle: Text(_docs.where((d) => d.documentType == type).map((d) => '${d.filename} (${d.status})').join(', ')),
                    trailing: TextButton(key: Key('upload-$type'), onPressed: () => _upload(type), child: const Text('Upload')),
                  ),
                SectionTitle('Services', trailing: TextButton.icon(
                  key: const Key('add-service'),
                  onPressed: _addService, icon: const Icon(Icons.add), label: const Text('Add'))),
                if (p.services.isEmpty) const Text('Add the services you offer to see matching jobs.'),
                for (final s in p.services)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.categoryName),
                    subtitle: s.startingPrice == null ? null : Text('From ${rs(s.startingPrice)}'),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirm(context, 'Remove ${s.categoryName}?', 'You will stop getting these jobs.')) return;
                        if (!context.mounted) return;
                        await runAction(context, () => api.removeService(s.id));
                        _load();
                      },
                    ),
                  ),
                const SectionTitle('About you'),
                TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Short bio')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(controller: _exp, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Years of experience')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _radius, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Work radius (km)')),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _area, decoration: const InputDecoration(labelText: 'Areas you cover', hintText: 'e.g. Gulberg, Model Town')),
                const SectionTitle('Base location'),
                Text('Jobs are matched by distance from here. Customers never see it.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                KaamMap(
                  key: ValueKey(_base),
                  center: _base ?? LatLng(config.cityLat, config.cityLng),
                  zoom: _base == null ? 11 : 14,
                  pins: [if (_base != null) MapPin(_base!, icon: Icons.location_pin, color: Colors.red)],
                  onTap: (pt) => setState(() => _base = pt),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: _useMyLocation, icon: const Icon(Icons.my_location), label: const Text('Use my location')),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('save-profile'),
                  onPressed: _saving ? null : _save,
                  child: const Text('Save profile'),
                ),
                const SizedBox(height: 32),
              ]),
            ),
    );
  }
}

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog({required this.options});
  final List<ServiceCategory> options;
  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  int? _category;
  final _price = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add a service'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            key: const Key('service-category'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Service'),
            items: [for (final c in widget.options) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _price, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Starting price (optional)', prefixText: 'Rs ')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const Key('service-save'),
            onPressed: _category == null ? null : () => Navigator.pop(context, (_category!, _price.text.trim())),
            child: const Text('Add'),
          ),
        ],
      );
}
