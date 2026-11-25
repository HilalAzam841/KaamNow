import 'dart:async';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';

/// Asks before sending an SOS for this booking. Returns true when it was sent.
Future<bool> showSosDialog(BuildContext context, Booking booking) async {
  final t = context.t;
  final note = TextEditingController();
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.sos, color: Colors.red, size: 40),
      title: Text(t.sosTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t.sosBody),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sos-note'),
            controller: note,
            maxLength: 500,
            decoration: InputDecoration(labelText: t.sosNoteLabel),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t.cancel)),
        FilledButton(
          key: const Key('send-sos'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(d, true),
          child: Text(t.sendSos),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;
  final texted = await runAction(context, () => context.read<Session>().api.raiseSos(booking.id, note: note.text.trim()));
  if (texted == null || !context.mounted) return false;
  showInfo(context, '${t.sosSent} ${t.sosContactsTexted(texted)}');
  return true;
}

/// Banner on the booking page while the viewer's SOS is open.
class SosBanner extends StatelessWidget {
  const SosBanner({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Card(
        key: const Key('sos-banner'),
        color: Colors.red.shade50,
        child: ListTile(
          leading: const Icon(Icons.sos, color: Colors.red),
          title: Text(status == 'acknowledged' ? context.t.sosSeenBanner : context.t.sosOpenBanner),
        ),
      );
}

/// Makes (or replaces) a private link so family can follow the job. Returns true when sharing changed.
Future<bool> showShareSheet(BuildContext context, Booking booking) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareSheet(booking: booking),
  );
  return changed == true;
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.booking});
  final Booking booking;
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  TripShare? _share;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _make();
  }

  Future<void> _make({bool sendToContacts = false}) async {
    setState(() => _busy = true);
    try {
      final s = await context.read<Session>().api.shareBooking(widget.booking.id, sendToContacts: sendToContacts);
      if (!mounted) return;
      setState(() => _share = s);
      if (sendToContacts) showInfo(context, context.t.sosContactsTexted(s.contactsTexted));
    } catch (e) {
      if (!mounted) return;
      if (_share == null) {
        setState(() => _error = e);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final r = await runAction(context, () async {
      await context.read<Session>().api.stopSharing(widget.booking.id);
      return true;
    }, success: context.t.sharingStopped);
    if (r == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = _share;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.shareTrip, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (_error != null)
          ErrorView(error: _error!, onRetry: () {
            setState(() => _error = null);
            _make();
          })
        else if (s == null)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else ...[
          SelectableText(s.url, key: const Key('share-url'), textDirection: TextDirection.ltr),
          const SizedBox(height: 8),
          Text(t.shareTripHint(when(s.expiresAt)), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('copy-share'),
            icon: const Icon(Icons.copy),
            label: Text(t.copyLink),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: s.url));
              if (context.mounted) showInfo(context, t.linkCopied);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('text-contacts'),
            icon: const Icon(Icons.sms),
            label: Text(t.textMyContacts),
            onPressed: _busy ? null : () => _make(sendToContacts: true),
          ),
          TextButton(key: const Key('stop-sharing'), onPressed: _busy ? null : _stop, child: Text(t.stopSharing)),
        ],
      ]),
    );
  }
}

/// Up to 3 people who are texted when the user presses SOS.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});
  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _loader = GlobalKey<LoaderState<List<EmergencyContact>>>();

  Future<void> _add() async {
    final t = context.t;
    final name = TextEditingController();
    final phone = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.addContact),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              key: const Key('contact-name'),
              controller: name,
              decoration: InputDecoration(labelText: t.fullName),
              validator: (v) => (v ?? '').trim().length < 2 ? t.fullName : null,
            ),
            TextFormField(
              key: const Key('contact-phone'),
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t.contactPhoneLabel, hintText: '03001234567'),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'[\s-]'), '').length < 10 ? t.contactPhoneLabel : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('save-contact'),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(d, true);
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runAction(context,
        () => context.read<Session>().api.addEmergencyContact(name.text.trim(), phone.text.trim()),
        success: t.contactAdded);
    if (r != null) await _loader.currentState?.reload();
  }

  Future<void> _remove(EmergencyContact c) async {
    final t = context.t;
    if (!await confirm(context, t.removeContactQ(c.name), ltr(c.phone), ok: t.remove) || !mounted) return;
    final r = await runAction(context, () async {
      await context.read<Session>().api.removeEmergencyContact(c.id);
      return true;
    }, success: t.contactRemoved);
    if (r == true) await _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.emergencyContacts)),
      body: PageBody(
        child: Loader<List<EmergencyContact>>(
          key: _loader,
          load: context.read<Session>().api.emergencyContacts,
          builder: (context, contacts, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            if (contacts.isEmpty)
              EmptyView(icon: Icons.contact_phone, title: t.noEmergencyContacts, subtitle: t.noEmergencyContactsHint)
            else ...[
              Text(t.emergencyContactsHint, style: Theme.of(context).textTheme.bodySmall),
              for (final c in contacts)
                Card(
                  child: ListTile(
                    key: Key('contact-${c.id}'),
                    leading: const Icon(Icons.person),
                    title: Text(c.name),
                    subtitle: Text(ltr(c.phone)),
                    trailing: IconButton(
                      key: Key('remove-contact-${c.id}'),
                      tooltip: t.remove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(c),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (contacts.length < 3)
              FilledButton.icon(
                  key: const Key('add-contact'), onPressed: _add, icon: const Icon(Icons.add), label: Text(t.addContact))
            else
              Text(t.maxContactsReached, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

/// Public page for a shared link. Works without signing in.
class SharedJobScreen extends StatefulWidget {
  const SharedJobScreen({super.key, required this.token});
  final String token;
  @override
  State<SharedJobScreen> createState() => _SharedJobScreenState();
}

class _SharedJobScreenState extends State<SharedJobScreen> {
  final _loader = GlobalKey<LoaderState<SharedJob>>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keeps the status and the worker's position fresh while the page is open.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loader.currentState?.reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.sharedJobTitle)),
      body: PageBody(
        child: Loader<SharedJob>(
          key: _loader,
          load: () => context.read<Session>().api.sharedJob(widget.token),
          errorBuilder: (context, error, retry) =>
              EmptyView(key: const Key('share-expired'), icon: Icons.link_off, title: t.linkExpired),
          builder: (context, j, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(t.sharedByName(j.sharedBy == 'worker' ? j.workerName : j.customerName),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(j.title, style: Theme.of(context).textTheme.titleLarge)),
                StatusChip(j.status, key: const Key('shared-status')),
              ]),
              Text([j.categoryName, j.area].where((s) => s.isNotEmpty).join(' · ')),
              Text(whenWindow(j.preferredTime, j.durationMinutes)),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.engineering),
                  title: Text('${t.worker}: ${j.workerName}'),
                  subtitle: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    RatingLine(rating: j.workerRating, count: j.workerJobs),
                    Text(t.jobsDoneCount(j.workerJobs)),
                    if (j.workerVerified) Text(t.verifiedByKaamNow, style: const TextStyle(color: Colors.green)),
                  ]),
                ),
              ),
              if (j.workerLat != null && j.workerLng != null) ...[
                SectionTitle(t.workerPositionNow),
                KaamMap(
                  key: const Key('shared-map'),
                  center: LatLng(j.workerLat!, j.workerLng!),
                  pins: [MapPin(LatLng(j.workerLat!, j.workerLng!), icon: Icons.two_wheeler, color: Colors.blue)],
                ),
                if (j.locationAt != null) Text(ago(j.locationAt), style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              Text(t.sharedLinkEnds(when(j.expiresAt)), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}
