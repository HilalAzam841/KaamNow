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
import '../widgets/language_button.dart';
import '../widgets/map_view.dart';
import '../../l10n/l10n.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key, this.categoryId, this.initialPin});
  final int? categoryId;

  /// Starts with the job location already set (e.g. from a map).
  final LatLng? initialPin;
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
  int _duration = 120;
  bool _emergency = false;
  List<TimeSlot>? _slots;
  bool _slotsLoading = false;
  int _slotsCall = 0;
  final List<UploadFile> _images = [];
  bool _busy = false;
  bool _locating = false;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _category = widget.categoryId;
    _pin = widget.initialPin;
    final session = context.read<Session>();
    _address.text = session.user?.defaultAddress ?? '';
    session.api.categories().then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((_) {});
    if (_category != null && _pin != null) WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  static const durations = [60, 120, 180, 240, 360, 480];

  /// Loads the day's 2-hour slots and how many matching workers nearby are free in each.
  Future<void> _loadSlots() async {
    if (_category == null || _pin == null || _emergency) {
      setState(() => _slots = null);
      return;
    }
    final call = ++_slotsCall;
    setState(() => _slotsLoading = true);
    try {
      final slots = await context.read<Session>().api.timeSlots(
          category: _category!, lat: _pin!.latitude, lng: _pin!.longitude, date: _when);
      if (mounted && call == _slotsCall) setState(() => _slots = slots);
    } catch (_) {
      if (mounted && call == _slotsCall) setState(() => _slots = null);
    } finally {
      if (mounted && call == _slotsCall) setState(() => _slotsLoading = false);
    }
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: _when);
    if (date == null || !mounted) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, _when.hour, _when.minute));
    _loadSlots();
  }

  Widget _slotPicker(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(t.freeWorkersOn(day(_when)), style: theme.textTheme.titleSmall)),
        TextButton(key: const Key('slot-day'), onPressed: _pickDay, child: Text(t.otherDay)),
      ]),
      if (_slotsLoading && _slots == null)
        const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
      else if (_slots != null && _slots!.isEmpty)
        Text(t.noSlotsLeft, style: theme.textTheme.bodySmall)
      else if (_slots != null)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _slots!)
            ChoiceChip(
              key: Key('slot-${s.start.hour}'),
              selected: _when == s.start,
              label: Text('${clock(s.start)} · ${s.freeWorkers == 0 ? t.noneFree : t.nFree(s.freeWorkers)}'),
              onSelected: (_) => setState(() => _when = s.start),
            ),
        ]),
      if (_slots != null && _slots!.isNotEmpty && _slots!.every((s) => s.freeWorkers == 0))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(t.allBusyHint, style: theme.textTheme.bodySmall),
        ),
    ]);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final (fix, error) = await LocationService().current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) _pin = LatLng(fix.latitude, fix.longitude);
    });
    if (fix != null) _loadSlots();
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
    final dayChanged = !_sameDay(date, _when);
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    if (dayChanged) _loadSlots();
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_form.currentState!.validate()) return;
    if (_category == null) return showInfo(context, context.t.chooseService);
    if (_pin == null) return showInfo(context, context.t.setLocationFirst);
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
            durationMinutes: _duration,
            budget: _budget.text.trim(),
            isEmergency: _emergency,
            images: _images,
          );
      if (!mounted) return;
      showInfo(context, req.matchedWorkersCount == null
          ? context.t.jobPosted
          : context.t.jobPostedNotified(req.matchedWorkersCount!));
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
      appBar: AppBar(title: Text(context.t.postAJob), actions: const [LanguageButton()]),
      body: PageBody(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<int>(
              key: const Key('req-category'),
              initialValue: _categories.any((c) => c.id == _category) ? _category : null,
              decoration: InputDecoration(labelText: context.t.service),
              items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) {
                setState(() => _category = v);
                _loadSlots();
              },
              validator: (v) => v == null ? context.t.chooseAService : _fieldErrors['category'],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('req-title'),
              controller: _title,
              decoration: InputDecoration(labelText: context.t.titleLabel, hintText: context.t.titleHint),
              validator: (v) => (v ?? '').trim().length < 5 ? 'At least 5 characters' : _fieldErrors['title'],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('req-description'),
              controller: _description,
              maxLines: 4,
              decoration: InputDecoration(labelText: context.t.describeProblem, alignLabelWithHint: true),
              validator: (v) =>
                  (v ?? '').trim().length < 10 ? 'Add a little more detail (10+ characters)' : _fieldErrors['description'],
            ),
            SectionTitle(context.t.location),
            KaamMap(
              center: center,
              zoom: _pin == null ? 12 : 15,
              key: ValueKey(_pin),
              pins: [if (_pin != null) MapPin(_pin!, icon: Icons.location_pin, color: Colors.red, label: context.t.jobLocation)],
              onTap: (p) {
                setState(() => _pin = p);
                _loadSlots();
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(_pin == null ? context.t.tapMapToPin : context.t.pinPlaced,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(context.t.useMyLocation),
              ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('req-address'),
              controller: _address,
              decoration: InputDecoration(labelText: context.t.address, helperText: context.t.addressHelper),
              validator: (v) => (v ?? '').trim().length < 5 ? context.t.enterAddress : _fieldErrors['address'],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              decoration: InputDecoration(labelText: context.t.areaOptional, hintText: context.t.areaHint),
            ),
            SectionTitle(context.t.details),
            if (!_emergency && _slots != null) _slotPicker(context),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(context.t.preferredTime),
              subtitle: Text(_emergency ? when(_when) : whenWindow(_when, _duration)),
              trailing: TextButton(
                  key: const Key('req-pick-time'), onPressed: _pickTime, child: Text(context.t.change)),
            ),
            if (!_emergency)
              DropdownButtonFormField<int>(
                key: const Key('req-duration'),
                isExpanded: true,
                initialValue: _duration,
                decoration: InputDecoration(labelText: context.t.howLongJob, helperText: context.t.howLongJobHelp),
                items: [for (final d in durations) DropdownMenuItem(value: d, child: Text(durationLabel(d)))],
                onChanged: (v) => setState(() => _duration = v ?? 120),
              ),
            if (_fieldErrors['preferred_time'] != null)
              Text(_fieldErrors['preferred_time']!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextFormField(
              controller: _budget,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.t.budgetOptional, prefixText: context.t.rsPrefix),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return _fieldErrors['budget'];
                return double.tryParse(v!.trim()) == null ? context.t.enterNumber : _fieldErrors['budget'];
              },
            ),
            if (config.emergencyEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _emergency,
                onChanged: (v) {
                  setState(() => _emergency = v);
                  _loadSlots();
                },
                title: Text(context.t.emergency),
                subtitle: Text(context.t.emergencySubtitle(rs(config.emergencyFee))),
              ),
            SectionTitle(context.t.photosOptional),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < _images.length; i++)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_images[i].bytes, width: 84, height: 84, fit: BoxFit.cover),
                  ),
                  PositionedDirectional(
                    end: 0,
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
                OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo), label: Text(context.t.add)),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('req-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.t.postJobGetOffers),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
