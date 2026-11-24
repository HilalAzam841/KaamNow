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
import '../../l10n/l10n.dart';

Map<String, String> _docTypes(AppLocalizations t) =>
    {'cnic_front': t.docCnicFront, 'cnic_back': t.docCnicBack, 'certificate': t.docCertificate, 'other': t.docOther};

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
      success: context.t.profileSaved,
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
    await runAction(context, () => api.uploadDocument(type, file), success: context.t.docUploaded(_docTypes(context.t)[type]!));
    _load();
  }

  Future<void> _uploadPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (f == null || !mounted) return;
    final file = UploadFile(field: 'profile_picture', filename: f.name, bytes: await f.readAsBytes());
    if (!mounted) return;
    await runAction(context, () => api.uploadProfilePicture(file), success: context.t.photoUpdated);
    _load();
  }

  Future<void> _addService() async {
    final existing = _p!.services.map((s) => s.category).toSet();
    final options = _categories.where((c) => !existing.contains(c.id)).toList();
    if (options.isEmpty) return showInfo(context, context.t.allServicesOffered);
    final r = await showDialog<(int, String)>(context: context, builder: (_) => _AddServiceDialog(options: options));
    if (r == null || !mounted) return;
    await runAction(context, () => api.addService(r.$1, startingPrice: r.$2), success: context.t.serviceAdded);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final theme = Theme.of(context);
    final config = context.read<Session>().config;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.myWorkerProfile)),
      body: p == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : PageBody(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Stack(children: [
                    Avatar(name: p.fullName, url: p.profilePicture, radius: 36),
                    PositionedDirectional(
                      end: -4,
                      bottom: -4,
                      child: IconButton.filledTonal(
                          iconSize: 16, onPressed: _uploadPhoto, icon: const Icon(Icons.camera_alt), tooltip: context.t.changePhoto),
                    ),
                  ]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.fullName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      StatusChip(p.verificationStatus, label: statusLabel(p.verificationStatus)),
                      const SizedBox(height: 4),
                      RatingLine(rating: p.averageRating, count: p.ratingCount),
                    ]),
                  ),
                ]),
                if (p.verificationStatus == 'rejected' && p.rejectionReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(context.t.reasonLine(p.rejectionReason), style: TextStyle(color: theme.colorScheme.error)),
                  ),
                SectionTitle(context.t.verificationDocuments),
                Text(context.t.cnicPrivate, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final type in _docTypes(context.t).keys)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_docs.any((d) => d.documentType == type) ? Icons.check_circle : Icons.upload_file,
                        color: _docs.any((d) => d.documentType == type) ? Colors.green : null),
                    title: Text(_docTypes(context.t)[type]!),
                    subtitle: Text(_docs.where((d) => d.documentType == type).map((d) => '${d.filename} (${statusLabel(d.status)})').join(', ')),
                    trailing: TextButton(key: Key('upload-$type'), onPressed: () => _upload(type), child: Text(context.t.upload)),
                  ),
                SectionTitle(context.t.services, trailing: TextButton.icon(
                  key: const Key('add-service'),
                  onPressed: _addService, icon: const Icon(Icons.add), label: Text(context.t.add))),
                if (p.services.isEmpty) Text(context.t.addServicesToSeeJobs),
                for (final s in p.services)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.categoryName),
                    subtitle: s.startingPrice == null ? null : Text(context.t.fromPriceCap(rs(s.startingPrice))),
                    trailing: IconButton(
                      tooltip: context.t.remove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirm(context, context.t.removeServiceQ(s.categoryName), context.t.stopGettingJobs)) return;
                        if (!context.mounted) return;
                        await runAction(context, () => api.removeService(s.id));
                        _load();
                      },
                    ),
                  ),
                SectionTitle(context.t.aboutYou),
                TextField(controller: _bio, maxLines: 3, decoration: InputDecoration(labelText: context.t.shortBio)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(controller: _exp, keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: context.t.yearsExperience)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _radius, keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: context.t.workRadius)),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _area, decoration: InputDecoration(labelText: context.t.areasYouCover, hintText: context.t.areasHint)),
                SectionTitle(context.t.baseLocation),
                Text(context.t.baseLocationHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                KaamMap(
                  key: ValueKey(_base),
                  center: _base ?? LatLng(config.cityLat, config.cityLng),
                  zoom: _base == null ? 11 : 14,
                  pins: [if (_base != null) MapPin(_base!, icon: Icons.location_pin, color: Colors.red)],
                  onTap: (pt) => setState(() => _base = pt),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(onPressed: _useMyLocation, icon: const Icon(Icons.my_location), label: Text(context.t.useMyLocation)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('save-profile'),
                  onPressed: _saving ? null : _save,
                  child: Text(context.t.saveProfile),
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
        title: Text(context.t.addAService),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            key: const Key('service-category'),
            initialValue: _category,
            decoration: InputDecoration(labelText: context.t.service),
            items: [for (final c in widget.options) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _price, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.t.startingPriceOptional, prefixText: context.t.rsPrefix)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.cancel)),
          FilledButton(
            key: const Key('service-save'),
            onPressed: _category == null ? null : () => Navigator.pop(context, (_category!, _price.text.trim())),
            child: Text(context.t.add),
          ),
        ],
      );
}
