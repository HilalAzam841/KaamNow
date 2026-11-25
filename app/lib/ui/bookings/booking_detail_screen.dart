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
import '../widgets/language_button.dart';
import '../widgets/map_view.dart';
import '../widgets/offer_widgets.dart';
import 'promo_box.dart';
import '../../l10n/l10n.dart';

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
  DiscountChoice _discount = const DiscountChoice();
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
        if (mounted) setState(() => _shareError = context.t.couldNotSendLocation);
        return;
      }
    }
    if (mounted && _shareError != null) setState(() => _shareError = null);
  }

  // ---- actions ------------------------------------------------------------
  Future<void> _advance(String next) async {
    final b = await runAction(context, () => api.updateBookingStatus(widget.id, next),
        success: context.t.statusUpdated(statusLabel(next)));
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
        title: Text(context.t.completionCode),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.t.completionCodeHint),
          const SizedBox(height: 16),
          Text(code, key: const Key('otp-code'),
              style: Theme.of(c).textTheme.displaySmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (expires != null) Text(c.t.validUntil(when(expires)), style: Theme.of(c).textTheme.bodySmall),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(context.t.done))],
      ),
    );
  }

  Future<void> _confirmDone() async {
    if (!await confirm(context, context.t.markCompleteQ, context.t.onlyIfDone, ok: context.t.complete)) return;
    if (!mounted) return;
    final b = await runAction(context, () => api.confirmCompletion(widget.id), success: context.t.jobCompleted);
    if (b != null) _load();
  }

  Future<void> _completeWithCode() async {
    final code = await promptText(context, context.t.enterCompletionCode,
        label: context.t.sixDigitCode, ok: context.t.completeJob, required: true, keyboard: TextInputType.number);
    if (code == null || !mounted) return;
    final b = await runAction(context, () => api.completeWithOtp(widget.id, code), success: context.t.jobCompleted);
    if (b != null) _load();
  }

  Future<void> _cancel() async {
    final reason = await promptText(context, context.t.cancelBookingQ, label: context.t.reason, ok: context.t.cancelBooking, required: true);
    if (reason == null || !mounted) return;
    final b = await runAction(context, () => api.cancelBooking(widget.id, reason), success: context.t.bookingCancelled);
    if (b != null) _load();
  }

  Future<void> _pay(String method) async {
    final d = _discount;
    final p = await runAction(
        context, () => api.createPayment(widget.id, method, promoCode: d.promoCode, useCredit: d.useCredit));
    if (p == null || !mounted) return;
    if (p.checkout != null) {
      final outcome = await openCheckout(context, p.checkout!);
      if (!mounted) return;
      showInfo(context, switch (outcome) {
        CheckoutOutcome.openedInNewTab => context.t.completePaymentNewTab,
        CheckoutOutcome.returned => context.t.paymentWindowClosed,
        CheckoutOutcome.failed => context.t.onlinePaymentUnavailable,
      });
    } else {
      showInfo(context, context.t.payCash);
    }
    _load();
  }

  Future<void> _confirmCash(Payment p) async {
    if (!await confirm(context, context.t.cashReceivedQ, context.t.confirmCashAmount(rs(p.amount)), ok: context.t.confirm)) return;
    if (!mounted) return;
    await runAction(context, () => api.confirmCashPayment(p.id), success: context.t.paymentConfirmed);
    _load();
  }

  Future<void> _review() async {
    final r = await showDialog<(int, String)>(context: context, builder: (_) => const _ReviewDialog());
    if (r == null || !mounted) return;
    await runAction(context, () => api.createReview(widget.id, r.$1, r.$2), success: context.t.thanksForReview);
    _load();
  }

  // ---- UI -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      appBar: AppBar(title: Text(b == null ? context.t.booking : context.t.bookingNumber(b.id)), actions: [
        if (b != null)
          IconButton(
            tooltip: context.t.chat,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/bookings/${b.id}/chat'),
          ),
        const LanguageButton(),
        if (b != null)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') context.push('/complaints/new?booking=${b.id}');
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(context.t.reportProblem))],
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
                      label: Text(context.t.rateWorker(b.worker.fullName.split(' ').first)),
                    ),
                  ],
                  SectionTitle(context.t.timeline),
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
          _priceRow(context.t.agreedPrice, rs(b.agreedPrice)),
          if ((double.tryParse(b.emergencyFee) ?? 0) > 0) _priceRow(context.t.emergencyFeeLabel, rs(b.emergencyFee)),
          _priceRow(context.t.total, rs(b.totalAmount), bold: true),
          if (_isWorker && b.commission != null) ...[
            const SizedBox(height: 6),
            Text(context.t.commissionKeep('${b.commission!['rate_percent']}', rs('${b.commission!['commission_amount']}'), rs('${b.commission!['worker_earning']}')), style: theme.textTheme.bodySmall),
          ],
          if (b.cancelReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(context.t.cancelledReason(b.cancelReason), style: TextStyle(color: theme.colorScheme.error)),
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
      SectionTitle(context.t.contact),
      Card(
        child: Column(children: [
          if (phone != null)
            ListTile(leading: const Icon(Icons.phone), title: Text(ltr('$phone')),
                subtitle: Text(_isWorker ? context.t.customer : context.t.worker)),
          if (c['address'] != null)
            ListTile(leading: const Icon(Icons.home), title: Text('${c['address']}'), subtitle: Text(context.t.jobAddress)),
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
      SectionTitle(_isWorker ? context.t.location : context.t.liveTracking),
      if (!_isWorker)
        Text(
          latest == null
              ? (b.status == 'confirmed' ? context.t.trackingStarts : context.t.waitingForWorkerLocation)
              : '${context.t.workerAway(b.worker.fullName.split(' ').first, latest.distanceKm?.toStringAsFixed(1) ?? '?')}'
                  '${latest.etaMinutes != null ? ' · ${context.t.aboutMinutes(latest.etaMinutes!)}' : ''} (${context.t.updatedAgo(ago(latest.recordedAt))})',
          key: const Key('tracking-text'),
        ),
      if (_isWorker)
        SwitchListTile(
          key: const Key('share-location'),
          contentPadding: EdgeInsets.zero,
          value: _sharing,
          onChanged: _toggleSharing,
          title: Text(context.t.shareLiveLocation),
          subtitle: Text(_shareError ?? (_sharing ? context.t.sendingEvery15 : context.t.off)),
        ),
      if (showMap) ...[
        const SizedBox(height: 8),
        KaamMap(
          key: ValueKey('${workerPoint?.latitude},${workerPoint?.longitude}'),
          center: workerPoint ?? job!,
          zoom: 14,
          trail: [for (final p in _location?.trail ?? <LocationPoint>[]) LatLng(p.latitude, p.longitude)],
          pins: [
            if (job != null) MapPin(job, icon: Icons.home_rounded, color: Colors.red, label: context.t.jobLocation),
            if (workerPoint != null) MapPin(workerPoint, icon: Icons.two_wheeler, color: Colors.blue, label: context.t.worker),
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
            'on_the_way' => context.t.imOnMyWay,
            'arrived' => context.t.iveArrived,
            _ => context.t.startWork,
          }),
        ));
      }
      if (b.status == 'in_progress') {
        buttons.add(FilledButton.icon(
          key: const Key('complete-otp'),
          onPressed: _completeWithCode,
          icon: const Icon(Icons.task_alt),
          label: Text(context.t.completeWithCode),
        ));
      }
    } else if (b.status == 'in_progress') {
      buttons.add(FilledButton.icon(
        key: const Key('issue-otp'),
        onPressed: _issueOtp,
        icon: const Icon(Icons.password),
        label: Text(context.t.getCompletionCode),
      ));
      buttons.add(OutlinedButton.icon(
        key: const Key('confirm-complete'),
        onPressed: _confirmDone,
        icon: const Icon(Icons.task_alt),
        label: Text(context.t.confirmJobDone),
      ));
    }
    if (const {'confirmed', 'on_the_way', 'arrived'}.contains(b.status)) {
      buttons.add(TextButton(key: const Key('cancel-booking'), onPressed: _cancel, child: Text(context.t.cancelBooking)));
    }
    if (buttons.isEmpty) return const [];
    return [const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: buttons)];
  }

  List<Widget> _payment(Booking b) {
    final theme = Theme.of(context);
    final live = _payments.where((p) => p.status == 'pending' || p.status == 'completed').toList();
    final current = live.isEmpty ? null : live.first;
    final widgets = <Widget>[SectionTitle(context.t.payment)];
    if (current?.status == 'completed') {
      widgets.add(Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(
            [
              context.t.paidAmount(rs(current!.amount)),
              if (current.hasDiscount && !_isWorker) '(${context.t.promoApplied(context.t.promoCode, rs(current.discountAmount))})',
            ].join(' '),
            key: const Key('payment-done'),
          ),
          subtitle: Text([
            context.t.methodRef(paymentMethodLabel(current.method), current.reference),
            if (current.hasRefund)
              _isWorker
                  ? context.t.refundedToCustomer(rs(current.refundedAmount))
                  : context.t.refundedToYou(rs(current.refundedAmount)),
          ].join('\n'), key: const Key('payment-done-detail')),
        ),
      ));
    } else if (current != null) {
      widgets.add(Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_top),
          title: Text(context.t.paymentPending(paymentMethodLabel(current.method), rs(current.amount))),
          subtitle: Text(current.method == 'cash'
              ? (_isWorker ? context.t.confirmOncePaid : context.t.waitingForWorkerConfirm)
              : context.t.waitingForGateway),
          trailing: _isWorker && current.method == 'cash'
              ? FilledButton(key: const Key('confirm-cash'), onPressed: () => _confirmCash(current), child: Text(context.t.received))
              : null,
        ),
      ));
    } else if (_isWorker) {
      widgets.add(Text(context.t.customerNotPaid));
    } else {
      final failed = _payments.where((p) => p.status == 'failed' || p.status == 'expired' || p.status == 'disputed');
      final refunded = _payments.where((p) => p.status == 'refunded');
      if (refunded.isNotEmpty) {
        widgets.add(Text(context.t.paymentRefunded(rs(refunded.first.amount)), key: const Key('payment-refunded')));
      } else if (failed.isNotEmpty) {
        widgets.add(Text(context.t.lastAttempt(statusLabel(failed.first.status), failed.first.failureReason),
            style: TextStyle(color: theme.colorScheme.error)));
      }
      widgets.add(Text(context.t.amountDue(rs(b.totalAmount))));
      widgets.add(const SizedBox(height: 8));
      widgets.add(PromoBox(bookingId: b.id, onChanged: (d) => setState(() => _discount = d)));
      widgets.add(Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in session.config.paymentMethods)
          OutlinedButton(
            key: Key('pay-${m.code}'),
            onPressed: m.available ? () => _pay(m.code) : null,
            child: Text(m.available ? context.t.payWith(paymentMethodLabel(m.code)) : context.t.comingSoon(paymentMethodLabel(m.code))),
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
        title: Text(context.t.rateThisJob),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('star-$i'),
                onPressed: () => setState(() => _rating = i),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 34),
              ),
          ]),
          TextField(controller: _comment, maxLines: 3, decoration: InputDecoration(labelText: context.t.commentOptional)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.cancel)),
          FilledButton(
            key: const Key('submit-review'),
            onPressed: () => Navigator.pop(context, (_rating, _comment.text.trim())),
            child: Text(context.t.submit),
          ),
        ],
      );
}
