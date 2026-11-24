import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key, this.categoryId});
  final int? categoryId;
  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _area = TextEditingController();
  final _budget = TextEditingController();
  List<ServiceCategory> _categories = [];
  int? _category;
  LatLng? _pin;
  DateTime _when = DateTime.now().add(const Duration(hours: 2));
  bool _emergency = false;
  final List<UploadFile> _images = [];
  bool _busy = false;
  bool _locating = false;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _category = widget.categoryId;
    final session = context.read<Session>();
    _address.text = session.user?.defaultAddress ?? '';
    session.api.categories().then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((_) {});
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final (fix, error) = await LocationService().current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) _pin = LatLng(fix.latitude, fix.longitude);
    });
    if (error != null) showInfo(context, error);
  }

  Future<void> _pickImages() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
    for (final f in files.take(5 - _images.length)) {
      _images.add(UploadFile(field: 'images', filename: f.name, bytes: await f.readAsBytes()));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: _when);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_form.currentState!.validate()) return;
    if (_category == null) return showInfo(context, 'Choose a service.');
    if (_pin == null) return showInfo(context, 'Set the job location on the map, or use your current location.');
    setState(() => _busy = true);
    try {
      final req = await context.read<Session>().api.createRequest(
            category: _category!,
            title: _title.text.trim(),
            description: _description.text.trim(),
            latitude: _pin!.latitude,
            longitude: _pin!.longitude,
            address: _address.text.trim(),
            area: _area.text.trim(),
            preferredTime: _when,
            budget: _budget.text.trim(),
            isEmergency: _emergency,
            images: _images,
          );
      if (!mounted) return;
      showInfo(context, req.matchedWorkersCount == null
          ? 'Job posted.'
          : 'Job posted. ${req.matchedWorkersCount} nearby workers were notified.');
      context.pushReplacement('/requests/${req.id}');
    } on ApiException catch (e) {
      setState(() => _fieldErrors = e.fieldErrors);
      _form.currentState!.validate();
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Session>().config;
    final center = _pin ?? LatLng(config.cityLat, config.cityLng);
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: PageBody(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<int>(
              key: const Key('req-category'),
              initialValue: _categories.any((c) => c.id == _category) ? _category : null,
              decoration: const InputDecoration(labelText: 'Service'),
              items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _category = v),
              validator: (v) => v == null ? 'Choose a service' : _fieldErrors['category'],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('req-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Ceiling fan not working'),
              validator: (v) => (v ?? '').trim().length < 5 ? 'At least 5 characters' : _fieldErrors['title'],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('req-description'),
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Describe the problem', alignLabelWithHint: true),
              validator: (v) =>
                  (v ?? '').trim().length < 10 ? 'Add a little more detail (10+ characters)' : _fieldErrors['description'],
            ),
            const SectionTitle('Location'),
            KaamMap(
              center: center,
              zoom: _pin == null ? 12 : 15,
              key: ValueKey(_pin),
              pins: [if (_pin != null) MapPin(_pin!, icon: Icons.location_pin, color: Colors.red, label: 'Job location')],
              onTap: (p) => setState(() => _pin = p),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(_pin == null ? 'Tap the map to place the pin.' : 'Pin placed. Tap the map to move it.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: const Text('Use my location'),
              ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('req-address'),
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address', helperText: 'Only the worker you book will see it'),
              validator: (v) => (v ?? '').trim().length < 5 ? 'Enter the address' : _fieldErrors['address'],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(labelText: 'Area (optional)', hintText: 'e.g. DHA Phase 5'),
            ),
            const SectionTitle('Details'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Preferred time'),
              subtitle: Text(when(_when)),
              trailing: TextButton(onPressed: _pickTime, child: const Text('Change')),
            ),
            if (_fieldErrors['preferred_time'] != null)
              Text(_fieldErrors['preferred_time']!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextFormField(
              controller: _budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your budget (optional)', prefixText: 'Rs '),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return _fieldErrors['budget'];
                return double.tryParse(v!.trim()) == null ? 'Enter a number' : _fieldErrors['budget'];
              },
            ),
            if (config.emergencyEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _emergency,
                onChanged: (v) => setState(() => _emergency = v),
                title: const Text('Emergency'),
                subtitle: Text('Shown first to workers. Adds ${rs(config.emergencyFee)} to the total.'),
              ),
            const SectionTitle('Photos (optional)'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < _images.length; i++)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_images[i].bytes, width: 84, height: 84, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _images.removeAt(i)),
                    ),
                  ),
                ]),
              if (_images.length < 5)
                OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo), label: const Text('Add')),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('req-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post job and get offers'),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
