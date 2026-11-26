import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';

const maxSavedAddresses = 10;

String addressTitle(BuildContext context, SavedAddress a) => switch (a.label) {
      'home' => context.t.labelHome,
      'work' => context.t.labelWork,
      _ => a.name.isEmpty ? context.t.labelOther : a.name,
    };

IconData addressIcon(String label) => switch (label) {
      'home' => Icons.home,
      'work' => Icons.work,
      _ => Icons.place,
    };

/// Opens the add/edit form. Returns the saved address, or null when cancelled.
Future<SavedAddress?> editAddress(BuildContext context,
    {SavedAddress? existing, LatLng? pin, String address = '', String area = ''}) {
  return Navigator.of(context).push<SavedAddress>(MaterialPageRoute(
    builder: (_) => AddressFormScreen(existing: existing, pin: pin, address: address, area: area),
  ));
}

/// The customer's saved places: add, edit, delete and choose which comes first.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _loader = GlobalKey<LoaderState<List<SavedAddress>>>();

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _act(String action, SavedAddress a) async {
    final t = context.t;
    final api = context.read<Session>().api;
    switch (action) {
      case 'edit':
        if (await editAddress(context, existing: a) != null) await _reload();
      case 'default':
        if (await runAction(context, () => api.makeDefaultAddress(a.id)) != null) await _reload();
      case 'delete':
        if (!await confirm(context, t.deleteAddressQ, a.address, ok: t.remove) || !mounted) return;
        final r = await runAction(context, () async {
          await api.deleteAddress(a.id);
          return true;
        }, success: t.addressDeleted);
        if (r == true) await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.savedAddresses)),
      body: PageBody(
        child: Loader<List<SavedAddress>>(
          key: _loader,
          load: context.read<Session>().api.savedAddresses,
          builder: (context, list, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            if (list.isEmpty)
              EmptyView(icon: Icons.bookmark_border, title: t.noSavedAddresses, subtitle: t.noSavedAddressesHint)
            else
              for (final a in list)
                Card(
                  child: ListTile(
                    key: Key('address-${a.id}'),
                    leading: Icon(addressIcon(a.label)),
                    title: Row(children: [
                      Flexible(child: Text(addressTitle(context, a))),
                      if (a.isDefault) ...[
                        const SizedBox(width: 8),
                        StatusChip('active', label: t.addressDefaultBadge),
                      ],
                    ]),
                    subtitle: Text([a.address, if (a.area.isNotEmpty) a.area].join('\n')),
                    isThreeLine: a.area.isNotEmpty,
                    onTap: () => _act('edit', a),
                    trailing: PopupMenuButton<String>(
                      key: Key('address-menu-${a.id}'),
                      onSelected: (v) => _act(v, a),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(t.editAddress)),
                        if (!a.isDefault) PopupMenuItem(value: 'default', child: Text(t.makeDefault)),
                        PopupMenuItem(value: 'delete', child: Text(t.remove)),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            if (list.length < maxSavedAddresses)
              FilledButton.icon(
                key: const Key('add-address'),
                onPressed: () async {
                  if (await editAddress(context) != null) await _reload();
                },
                icon: const Icon(Icons.add_location_alt),
                label: Text(t.addAddress),
              )
            else
              Text(t.maxAddressesReached, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

/// Add or edit one saved address: label, pin on the map, address and area.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.existing, this.pin, this.address = '', this.area = ''});
  final SavedAddress? existing;
  final LatLng? pin;
  final String address;
  final String area;
  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late String _label = widget.existing?.label ?? 'home';
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? widget.address);
  late final _area = TextEditingController(text: widget.existing?.area ?? widget.area);
  late LatLng? _pin =
      widget.existing != null ? LatLng(widget.existing!.latitude, widget.existing!.longitude) : widget.pin;
  late bool _first = widget.existing?.isDefault ?? false;
  bool _busy = false;
  bool _locating = false;

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

  Future<void> _save() async {
    final t = context.t;
    if (!_form.currentState!.validate()) return;
    if (_pin == null) return showInfo(context, t.setPinFirst);
    final fields = <String, dynamic>{
      'label': _label,
      'name': _label == 'other' ? _name.text.trim() : '',
      'address': _address.text.trim(),
      'area': _area.text.trim(),
      'latitude': _pin!.latitude.toStringAsFixed(6),
      'longitude': _pin!.longitude.toStringAsFixed(6),
      if (_first && widget.existing?.isDefault != true) 'make_default': true,
    };
    setState(() => _busy = true);
    final api = context.read<Session>().api;
    final saved = await runAction(
        context, () => widget.existing == null ? api.addAddress(fields) : api.updateAddress(widget.existing!.id, fields),
        success: t.addressSaved);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved != null) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final config = context.read<Session>().config;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? t.addAddress : t.editAddress)),
      body: PageBody(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              key: const Key('address-label'),
              segments: [
                ButtonSegment(value: 'home', icon: const Icon(Icons.home), label: Text(t.labelHome)),
                ButtonSegment(value: 'work', icon: const Icon(Icons.work), label: Text(t.labelWork)),
                ButtonSegment(value: 'other', icon: const Icon(Icons.place), label: Text(t.labelOther)),
              ],
              selected: {_label},
              onSelectionChanged: (s) => setState(() => _label = s.first),
            ),
            if (_label == 'other') ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('address-name'),
                controller: _name,
                maxLength: 40,
                decoration: InputDecoration(labelText: t.placeNameLabel, hintText: t.placeNameHint),
                validator: (v) => (v ?? '').trim().isEmpty ? t.placeNameLabel : null,
              ),
            ],
            const SizedBox(height: 12),
            KaamMap(
              key: ValueKey(_pin),
              center: _pin ?? LatLng(config.cityLat, config.cityLng),
              zoom: _pin == null ? 12 : 16,
              pins: [if (_pin != null) MapPin(_pin!, icon: Icons.location_pin, color: Colors.red)],
              onTap: (p) => setState(() => _pin = p),
            ),
            Row(children: [
              Expanded(
                child: Text(_pin == null ? t.tapMapToPin : t.pinPlaced, style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: const Icon(Icons.my_location),
                label: Text(t.useMyLocation),
              ),
            ]),
            TextFormField(
              key: const Key('address-text'),
              controller: _address,
              decoration: InputDecoration(labelText: t.address, helperText: t.addressHelper),
              validator: (v) => (v ?? '').trim().length < 5 ? t.enterAddress : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('address-area'),
              controller: _area,
              decoration: InputDecoration(labelText: t.areaOptional, hintText: t.areaHint),
            ),
            SwitchListTile(
              key: const Key('address-first'),
              contentPadding: EdgeInsets.zero,
              title: Text(t.useFirstSwitch),
              value: _first,
              onChanged: widget.existing?.isDefault == true ? null : (v) => setState(() => _first = v),
            ),
            const SizedBox(height: 8),
            FilledButton(key: const Key('save-address'), onPressed: _busy ? null : _save, child: Text(t.save)),
          ]),
        ),
      ),
    );
  }
}
