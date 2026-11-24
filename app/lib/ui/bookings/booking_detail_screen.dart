import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/kaamnow_api.dart';
import '../../core/booking_socket.dart';
import '../../core/checkout_launcher.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';
import '../widgets/offer_widgets.dart';

/// One booking, for either side: status, contact, live tracking, completion, payment, review.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.id});
  final int id;
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final Session session = context.read<Session>();
  KaamNowApi get api => session.api;
  late final BookingSocket socket = BookingSocket(bookingId: widget.id, tokens: session.tokens);
  StreamSubscription<SocketEvent>? _sub;

  Booking? _booking;
  ServiceRequest? _request; // customer side: job coordinates for the map
  List<Payment> _payments = [];
  LiveLocation? _location;
  Object? _error;

  Timer? _shareTimer;
  bool _sharing = false;
  String? _shareError;

  bool get _isWorker => session.user?.isWorker == true;

  @override
  void initState() {
    super.initState();
    _sub = socket.events.listen(_onEvent);
    socket.connect();
    _load();
  }

  @override
  void dispose() {
    _shareTimer?.cancel();
    _sub?.cancel();
    socket.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await api.booking(widget.id);
      final payments = b.isCompleted ? await api.paymentsForBooking(b.id) : <Payment>[];
      LiveLocation? loc;
      if (b.isActive) {
        loc = await api.location(b.id).catchError((_) => LiveLocation());
      }
      ServiceRequest? req = _request;
      if (!_isWorker && req == null) {
        try {
          req = await api.request(b.requestId);
        } catch (_) {
          // The map just shows the worker without the job pin.
        }
      }
      if (!mounted) return;
      setState(() {
        _booking = b;
        _payments = payments;
        _location = loc;
        _request = req;
        _error = null;
      });
      if (!b.isActive) _stopSharing();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onEvent(SocketEvent e) {
    if (e.type == 'booking.status') {
      _load();
    } else if (e.type == 'location.update') {
      setState(() {
        final p = LocationPoint.fromJson(e.data);
        _location = LiveLocation(latest: p, trail: [...?_location?.trail, p]);
      });
    }
  }

  // ---- worker live location -------------------------------------------
  void _toggleSharing(bool on) => on ? _startSharing() : _stopSharing();

  void _startSharing() {
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    _shareOnce();
    _shareTimer = Timer.periodic(const Duration(seconds: 15), (_) => _shareOnce());
  }

  void _stopSharing() {
    _shareTimer?.cancel();
    _shareTimer = null;
    if (mounted && _sharing) setState(() => _sharing = false);
  }

  Future<void> _shareOnce() async {
    final (fix, error) = await LocationService().current();
    if (!mounted) return;
    if (fix == null) {
      setState(() => _shareError = error);
      return;
    }
    final sentLive = socket.send({
      'type': 'location.update',
      'latitude': fix.latitude,
      'longitude': fix.longitude,
      'accuracy_m': ?fix.accuracy,
      'speed_kmh': ?fix.speedKmh,
      'heading': ?fix.heading,
    });
    if (!sentLive) {
      try {
        await api.shareLocation(widget.id, fix.latitude, fix.longitude,
            accuracy: fix.accuracy, speedKmh: fix.speedKmh, heading: fix.heading);
      } catch (e) {
        if (mounted) setState(() => _shareError = 'Could not send your location.');
        return;
      }
    }
    if (mounted && _shareError != null) setState(() => _shareError = null);
  }

  // ---- actions ------------------------------------------------------------
  Future<void> _advance(String next) async {
    final b = await runAction(context, () => api.updateBookingStatus(widget.id, next),
        success: 'Status updated: ${bookingStatusLabel(next)}');
    if (b != null) {
      setState(() => _booking = b);
      if (next == 'on_the_way' && !_sharing) _startSharing();
    }
  }

  Future<void> _issueOtp() async {
    final r = await runAction(context, () => api.issueCompletionOtp(widget.id));
    if (r == null || !mounted) return;
    final (code, expires) = r;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Completion code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Give this code to the worker only when the job is done to your satisfaction.'),
          const SizedBox(height: 16),
          Text(code, key: const Key('otp-code'),
              style: Theme.of(c).textTheme.displaySmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (expires != null) Text('Valid until ${when(expires)}', style: Theme.of(c).textTheme.bodySmall),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
      ),
    );
  }

  Future<void> _confirmDone() async {
    if (!await confirm(context, 'Mark the job as complete?', 'Only confirm if the work is done.', ok: 'Complete')) return;
    if (!mounted) return;
    final b = await runAction(context, () => api.confirmCompletion(widget.id), success: 'Job completed.');
    if (b != null) _load();
  }

  Future<void> _completeWithCode() async {
    final code = await promptText(context, 'Enter completion code',
        label: '6-digit code from the customer', ok: 'Complete job', required: true, keyboard: TextInputType.number);
    if (code == null || !mounted) return;
    final b = await runAction(context, () => api.completeWithOtp(widget.id, code), success: 'Job completed.');
    if (b != null) _load();
  }

  Future<void> _cancel() async {
    final reason = await promptText(context, 'Cancel this booking?', label: 'Reason', ok: 'Cancel booking', required: true);
    if (reason == null || !mounted) return;
    final b = await runAction(context, () => api.cancelBooking(widget.id, reason), success: 'Booking cancelled.');
    if (b != null) _load();
  }

  Future<void> _pay(String method) async {
    final p = await runAction(context, () => api.createPayment(widget.id, method));
    if (p == null || !mounted) return;
    if (p.checkout != null) {
      if (openCheckout(p.checkout!)) {
        showInfo(context, 'Complete the payment in the new tab. This page updates once the gateway confirms it.');
      } else {
        showInfo(context, 'Online payment is not available on this device yet.');
      }
    } else {
      showInfo(context, 'Pay the worker in cash. They will confirm when they receive it.');
    }
    _load();
  }

  Future<void> _confirmCash(Payment p) async {
    if (!await confirm(context, 'Cash received?', 'Confirm you received ${rs(p.amount)} in cash.', ok: 'Confirm')) return;
    if (!mounted) return;
    await runAction(context, () => api.confirmCashPayment(p.id), success: 'Payment confirmed.');
    _load();
  }

  Future<void> _review() async {
    final r = await showDialog<(int, String)>(context: context, builder: (_) => const _ReviewDialog());
    if (r == null || !mounted) return;
    await runAction(context, () => api.createReview(widget.id, r.$1, r.$2), success: 'Thanks for your review!');
    _load();
  }

  // ---- UI -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      appBar: AppBar(title: Text(b == null ? 'Booking' : 'Booking #${b.id}'), actions: [
        if (b != null)
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/bookings/${b.id}/chat'),
          ),
        if (b != null)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') context.push('/complaints/new?booking=${b.id}');
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report a problem'))],
          ),
      ]),
      body: b == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: PageBody(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  _header(b),
                  if (b.isActive) ..._contact(b),
                  if (b.isActive) ..._tracking(b),
                  ..._actions(b),
                  if (b.isCompleted) ..._payment(b),
                  if (b.isCompleted && !_isWorker && !b.hasReview) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      key: const Key('leave-review'),
                      onPressed: _review,
                      icon: const Icon(Icons.star),
                      label: Text('Rate ${b.worker.fullName.split(' ').first}'),
                    ),
                  ],
                  const SectionTitle('Timeline'),
                  for (final log in b.statusHistory.reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.radio_button_checked, size: 18),
                      title: Text(bookingStatusLabel(log.toStatus)),
                      subtitle: log.note.isEmpty ? null : Text(log.note),
                      trailing: Text(when(log.createdAt)),
                    ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }

  Widget _header(Booking b) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(b.title, style: theme.textTheme.titleLarge)),
            StatusChip(b.status, key: const Key('booking-status')),
          ]),
          Text('${b.categoryName} · ${when(b.preferredTime)}'),
          const Divider(height: 24),
          if (_isWorker)
            Row(children: [const Icon(Icons.person), const SizedBox(width: 8), Text(b.customerName, style: theme.textTheme.titleMedium)])
          else
            WorkerSummary(worker: b.worker, onTap: () => context.push('/workers/${b.worker.id}')),
          const Divider(height: 24),
          _priceRow('Agreed price', rs(b.agreedPrice)),
          if ((double.tryParse(b.emergencyFee) ?? 0) > 0) _priceRow('Emergency fee', rs(b.emergencyFee)),
          _priceRow('Total', rs(b.totalAmount), bold: true),
          if (_isWorker && b.commission != null) ...[
            const SizedBox(height: 6),
            Text('KaamNow commission ${b.commission!['rate_percent']}%: ${rs('${b.commission!['commission_amount']}')}. '
                'You keep ${rs('${b.commission!['worker_earning']}')}.', style: theme.textTheme.bodySmall),
          ],
          if (b.cancelReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Cancelled: ${b.cancelReason}', style: TextStyle(color: theme.colorScheme.error)),
          ],
        ]),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: bold ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16) : null),
        ]),
      );

  List<Widget> _contact(Booking b) {
    final c = b.contact;
    if (c.isEmpty) return const [];
    final phone = c['customer_phone'] ?? c['worker_phone'];
    return [
      const SectionTitle('Contact'),
      Card(
        child: Column(children: [
          if (phone != null)
            ListTile(leading: const Icon(Icons.phone), title: Text('$phone'),
                subtitle: Text(_isWorker ? 'Customer' : 'Worker')),
          if (c['address'] != null)
            ListTile(leading: const Icon(Icons.home), title: Text('${c['address']}'), subtitle: const Text('Job address')),
        ]),
      ),
    ];
  }

  LatLng? get _jobPoint {
    final c = _booking?.contact ?? const {};
    final lat = parseDouble(c['latitude']) ?? _request?.latitude;
    final lng = parseDouble(c['longitude']) ?? _request?.longitude;
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  List<Widget> _tracking(Booking b) {
    final job = _jobPoint;
    final latest = _location?.latest;
    final workerPoint = latest == null ? null : LatLng(latest.latitude, latest.longitude);
    final showMap = job != null || workerPoint != null;
    return [
      SectionTitle(_isWorker ? 'Location' : 'Live tracking'),
      if (!_isWorker)
        Text(
          latest == null
              ? (b.status == 'confirmed' ? 'Tracking starts when the worker sets off.' : 'Waiting for the worker’s location…')
              : '${b.worker.fullName.split(' ').first} is ${latest.distanceKm?.toStringAsFixed(1) ?? '?'} km away'
                  '${latest.etaMinutes != null ? ' · about ${latest.etaMinutes} min' : ''} (updated ${ago(latest.recordedAt)})',
          key: const Key('tracking-text'),
        ),
      if (_isWorker)
        SwitchListTile(
          key: const Key('share-location'),
          contentPadding: EdgeInsets.zero,
          value: _sharing,
          onChanged: _toggleSharing,
          title: const Text('Share my live location with the customer'),
          subtitle: Text(_shareError ?? (_sharing ? 'Sending every 15 seconds while this page is open.' : 'Off')),
        ),
      if (showMap) ...[
        const SizedBox(height: 8),
        KaamMap(
          key: ValueKey('${workerPoint?.latitude},${workerPoint?.longitude}'),
          center: workerPoint ?? job!,
          zoom: 14,
          trail: [for (final p in _location?.trail ?? <LocationPoint>[]) LatLng(p.latitude, p.longitude)],
          pins: [
            if (job != null) MapPin(job, icon: Icons.home_rounded, color: Colors.red, label: 'Job location'),
            if (workerPoint != null) MapPin(workerPoint, icon: Icons.two_wheeler, color: Colors.blue, label: 'Worker'),
          ],
        ),
      ],
    ];
  }

  List<Widget> _actions(Booking b) {
    final buttons = <Widget>[];
    if (_isWorker) {
      final next = b.nextWorkerStatus;
      if (next != null) {
        buttons.add(FilledButton.icon(
          key: const Key('advance-status'),
          onPressed: () => _advance(next),
          icon: const Icon(Icons.arrow_forward),
          label: Text(switch (next) {
            'on_the_way' => 'I’m on my way',
            'arrived' => 'I’ve arrived',
            _ => 'Start work',
          }),
        ));
      }
      if (b.status == 'in_progress') {
        buttons.add(FilledButton.icon(
          key: const Key('complete-otp'),
          onPressed: _completeWithCode,
          icon: const Icon(Icons.task_alt),
          label: const Text('Complete with customer’s code'),
        ));
      }
    } else if (b.status == 'in_progress') {
      buttons.add(FilledButton.icon(
        key: const Key('issue-otp'),
        onPressed: _issueOtp,
        icon: const Icon(Icons.password),
        label: const Text('Get completion code'),
      ));
      buttons.add(OutlinedButton.icon(
        key: const Key('confirm-complete'),
        onPressed: _confirmDone,
        icon: const Icon(Icons.task_alt),
        label: const Text('Confirm job is done'),
      ));
    }
    if (const {'confirmed', 'on_the_way', 'arrived'}.contains(b.status)) {
      buttons.add(TextButton(key: const Key('cancel-booking'), onPressed: _cancel, child: const Text('Cancel booking')));
    }
    if (buttons.isEmpty) return const [];
    return [const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: buttons)];
  }

  List<Widget> _payment(Booking b) {
    final theme = Theme.of(context);
    final live = _payments.where((p) => p.status == 'pending' || p.status == 'completed').toList();
    final current = live.isEmpty ? null : live.first;
    final widgets = <Widget>[const SectionTitle('Payment')];
    if (current?.status == 'completed') {
      widgets.add(Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text('Paid ${rs(current!.amount)}', key: const Key('payment-done')),
          subtitle: Text('${humanize(current.method)} · ref ${current.reference}'),
        ),
      ));
    } else if (current != null) {
      widgets.add(Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_top),
          title: Text('${humanize(current.method)} payment of ${rs(current.amount)} pending'),
          subtitle: Text(current.method == 'cash'
              ? (_isWorker ? 'Confirm once the customer has paid you.' : 'Waiting for the worker to confirm.')
              : 'Waiting for the payment gateway to confirm.'),
          trailing: _isWorker && current.method == 'cash'
              ? FilledButton(key: const Key('confirm-cash'), onPressed: () => _confirmCash(current), child: const Text('Received'))
              : null,
        ),
      ));
    } else if (_isWorker) {
      widgets.add(const Text('The customer has not paid yet.'));
    } else {
      final failed = _payments.where((p) => p.status == 'failed' || p.status == 'expired' || p.status == 'disputed');
      if (failed.isNotEmpty) {
        widgets.add(Text('Last attempt: ${humanize(failed.first.status)}. ${failed.first.failureReason}',
            style: TextStyle(color: theme.colorScheme.error)));
      }
      widgets.add(Text('Amount due: ${rs(b.totalAmount)}'));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in session.config.paymentMethods)
          OutlinedButton(
            key: Key('pay-${m.code}'),
            onPressed: m.available ? () => _pay(m.code) : null,
            child: Text(m.available ? 'Pay with ${m.label}' : '${m.label} (coming soon)'),
          ),
      ]));
    }
    return widgets;
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _comment = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rate this job'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('star-$i'),
                onPressed: () => setState(() => _rating = i),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 34),
              ),
          ]),
          TextField(controller: _comment, maxLines: 3, decoration: const InputDecoration(labelText: 'Comment (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const Key('submit-review'),
            onPressed: () => Navigator.pop(context, (_rating, _comment.text.trim())),
            child: const Text('Submit'),
          ),
        ],
      );
}
