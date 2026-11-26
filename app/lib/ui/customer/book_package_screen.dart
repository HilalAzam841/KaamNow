import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/package_widgets.dart';
import 'addresses_screen.dart';

/// Books a fixed-price package: pick a time the worker is free and an address, then confirm.
/// No bidding: the booking is confirmed straight away at the package price.
class BookPackageScreen extends StatefulWidget {
  const BookPackageScreen({super.key, required this.packageId, this.locate});
  final int packageId;

  /// Replaces GPS in tests.
  final Future<(LocationFix?, String?)> Function()? locate;

  @override
  State<BookPackageScreen> createState() => _BookPackageScreenState();
}

class _BookPackageScreenState extends State<BookPackageScreen> {
  ServicePackage? _package;
  Object? _loadError;
  List<SavedAddress> _saved = [];
  int? _savedId;
  LocationFix? _fix;
  bool _locating = false;
  final _address = TextEditingController();
  final _area = TextEditingController();
  final _notes = TextEditingController();
  DateTime _day = DateTime.now();
  List<WorkerSlot>? _slots;
  bool _slotsLoading = false;
  int _slotsCall = 0;
  DateTime? _when;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<Session>().api;
    setState(() => _loadError = null);
    try {
      final p = await api.package(widget.packageId);
      if (!mounted) return;
      setState(() => _package = p);
      _loadSlots();
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
      return;
    }
    try {
      final list = await api.savedAddresses();
      if (!mounted) return;
      setState(() {
        _saved = list;
        _savedId = (list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull)?.id;
      });
    } catch (_) {}
  }

  Future<void> _loadSlots() async {
    final w = _package?.worker;
    if (w == null) return;
    final call = ++_slotsCall;
    setState(() {
      _slotsLoading = true;
      _slots = null;
    });
    try {
      final slots = await context.read<Session>().api.workerSlots(w.id, _day);
      if (!mounted || call != _slotsCall) return;
      setState(() {
        _slots = slots;
        if (_when != null && !slots.any((s) => s.free && s.start == _when)) _when = null;
      });
    } catch (_) {
      if (mounted && call == _slotsCall) setState(() => _slots = []);
    } finally {
      if (mounted && call == _slotsCall) setState(() => _slotsLoading = false);
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: _day);
    if (date == null || !mounted) return;
    setState(() {
      _day = date;
      _when = null;
    });
    _loadSlots();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final (fix, error) = await (widget.locate ?? LocationService().current)();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) {
        _fix = fix;
        _savedId = null;
      }
    });
    if (error != null) showInfo(context, error);
  }

  Future<void> _addPlace() async {
    final saved = await editAddress(context);
    if (saved == null || !mounted) return;
    setState(() {
      _saved = [..._saved, saved];
      _savedId = saved.id;
    });
  }

  Future<void> _book() async {
    final t = context.t;
    if (_when == null) return showInfo(context, t.pickATime);
    if (_savedId == null && _fix == null) return showInfo(context, t.packageChooseAddress);
    if (_savedId == null && _address.text.trim().length < 5) return showInfo(context, t.packageWriteAddress);
    setState(() => _busy = true);
    try {
      final booking = await context.read<Session>().api.bookPackage(
            widget.packageId,
            preferredTime: _when!,
            savedAddress: _savedId,
            latitude: _fix?.latitude,
            longitude: _fix?.longitude,
            address: _address.text.trim(),
            area: _area.text.trim(),
            notes: _notes.text.trim(),
          );
      if (!mounted) return;
      showInfo(context, t.packageBooked);
      context.pushReplacement('/bookings/${booking.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      showError(context, e);
      if (e.statusCode == 409) _loadSlots();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = _package;
    Widget body;
    if (_loadError != null) {
      body = ErrorView(error: _loadError!, onRetry: _load);
    } else if (p == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _form(context, p);
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.bookPackage), actions: const [LanguageButton()]),
      body: PageBody(child: body),
    );
  }

  Widget _form(BuildContext context, ServicePackage p) {
    final t = context.t;
    final theme = Theme.of(context);
    final slots = _slots;
    final firstName = (p.worker?.fullName ?? '').split(' ').first;
    return ListView(padding: const EdgeInsets.all(16), children: [
      PackageCard(package: p, showWorker: true),
      SectionTitle(t.packageWhen, trailing: TextButton(key: const Key('book-day'), onPressed: _pickDay, child: Text(t.otherDay))),
      Text(t.whenWorkerFree(firstName, day(_day)), style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      if (_slotsLoading)
        const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
      else if (slots != null && slots.isEmpty)
        Text(t.noSlotsLeft, style: theme.textTheme.bodySmall)
      else if (slots != null) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in slots)
            ChoiceChip(
              key: Key('book-slot-${s.start.hour}'),
              selected: _when == s.start,
              label: Text(clock(s.start)),
              onSelected: s.free ? (_) => setState(() => _when = s.start) : null,
            ),
        ]),
        if (!slots.any((s) => s.free))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t.workerNotFreeThatDay, style: theme.textTheme.bodySmall),
          ),
      ],
      SectionTitle(t.packageWhere),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final a in _saved)
          ChoiceChip(
            key: Key('book-addr-${a.id}'),
            avatar: Icon(addressIcon(a.label), size: 18),
            label: Text(addressTitle(context, a)),
            selected: _savedId == a.id,
            onSelected: (_) => setState(() {
              _savedId = a.id;
              _fix = null;
            }),
          ),
        if (_saved.length < maxSavedAddresses)
          ActionChip(
            key: const Key('book-add-place'),
            avatar: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(t.addAddress),
            onPressed: _addPlace,
          ),
        ActionChip(
          key: const Key('book-my-location'),
          avatar: _locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location, size: 18),
          label: Text(t.useMyLocation),
          onPressed: _locating ? null : _useMyLocation,
        ),
      ]),
      if (_savedId != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_saved.firstWhere((a) => a.id == _savedId).address, style: theme.textTheme.bodySmall),
        ),
      if (_savedId == null && _fix != null) ...[
        TextField(
          key: const Key('book-address'),
          controller: _address,
          decoration: InputDecoration(labelText: t.address),
        ),
        TextField(
          key: const Key('book-area'),
          controller: _area,
          decoration: InputDecoration(labelText: t.areaOptional),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        key: const Key('book-notes'),
        controller: _notes,
        maxLength: 500,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(labelText: t.packageNotes, hintText: t.packageNotesHint),
      ),
      const SizedBox(height: 8),
      Card(
        color: theme.colorScheme.secondaryContainer,
        child: ListTile(
          leading: const Icon(Icons.verified_outlined),
          title: Text(t.packageTotal(rs(p.price)), key: const Key('book-total')),
          subtitle: Text(t.packageNoBidding),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('book-confirm'),
        onPressed: _busy ? null : _book,
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_circle_outline),
        label: Text(t.confirmBooking),
      ),
    ]);
  }
}
