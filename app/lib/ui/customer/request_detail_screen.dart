import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/kaamnow_api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/offer_widgets.dart';

const _sortOptions = {
  'price': 'Lowest price',
  'rating': 'Highest rating',
  'distance': 'Nearest',
  'eta': 'Fastest arrival',
  'completed_jobs': 'Most jobs',
  'experience': 'Most experience',
};

/// Customer view of one request: details plus every offer, with compare, counter, accept, reject.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.id});
  final int id;
  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late final KaamNowApi api = context.read<Session>().api;
  ServiceRequest? _request;
  List<WorkerOffer> _offers = [];
  String _sort = 'price';
  Object? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // New offers arrive as notifications; poll so the list stays fresh while open.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final results = await Future.wait([api.request(widget.id), api.offersForRequest(widget.id, ordering: _sort)]);
      if (!mounted) return;
      setState(() {
        _request = results[0] as ServiceRequest;
        _offers = (results[1] as Paged<WorkerOffer>).results;
        _error = null;
      });
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  Future<void> _accept(WorkerOffer o) async {
    final ok = await confirm(context, 'Book ${o.worker.fullName}?',
        'You agree to pay ${rs(o.currentPrice)}${_request!.isEmergency ? ' plus the ${rs(_request!.emergencyFee)} emergency fee' : ''}. '
        'All other offers will be closed.',
        ok: 'Book');
    if (!ok || !mounted) return;
    final booking = await runAction(context, () => api.acceptOffer(o.id), success: 'Booked!');
    if (booking != null && mounted) context.pushReplacement('/bookings/${booking.id}');
  }

  Future<void> _counter(WorkerOffer o) async {
    final r = await askCounter(context, o.currentPrice);
    if (r == null || !mounted) return;
    await runAction(context, () => api.negotiate(o.id, amount: r.$1, message: r.$2), success: 'Counter offer sent.');
    _load();
  }

  Future<void> _reject(WorkerOffer o) async {
    final reason = await promptText(context, 'Reject this offer?', label: 'Reason (optional)', ok: 'Reject');
    if (reason == null || !mounted) return;
    await runAction(context, () => api.rejectOffer(o.id, reason: reason));
    _load();
  }

  Future<void> _cancelRequest() async {
    final reason = await promptText(context, 'Cancel this request?', label: 'Reason', ok: 'Cancel request', required: true);
    if (reason == null || !mounted) return;
    await runAction(context, () => api.cancelRequest(widget.id, reason), success: 'Request cancelled.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request'),
        actions: [
          if (r != null && r.isOpen)
            IconButton(tooltip: 'Cancel request', onPressed: _cancelRequest, icon: const Icon(Icons.cancel_outlined)),
        ],
      ),
      body: r == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: PageBody(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  _RequestHeader(request: r),
                  if (r.bookingId != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: const Text('This job is booked'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/bookings/${r.bookingId}'),
                      ),
                    ),
                  SectionTitle(
                    'Offers (${_offers.length})',
                    trailing: _offers.length > 1
                        ? DropdownButton<String>(
                            value: _sort,
                            underline: const SizedBox(),
                            items: [for (final e in _sortOptions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                            onChanged: (v) {
                              setState(() => _sort = v!);
                              _load();
                            },
                          )
                        : null,
                  ),
                  if (_offers.isEmpty)
                    EmptyView(
                      icon: Icons.hourglass_top,
                      title: r.isOpen ? 'Waiting for offers' : 'No offers',
                      subtitle: r.isOpen ? 'Nearby workers have been notified. Offers appear here as they arrive.' : null,
                    ),
                  for (final o in _offers)
                    _OfferCard(
                      offer: o,
                      requestOpen: r.isOpen,
                      onAccept: () => _accept(o),
                      onCounter: () => _counter(o),
                      onReject: () => _reject(o),
                    ),
                ]),
              ),
            ),
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request});
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.title, style: theme.textTheme.titleLarge)),
            StatusChip(r.status),
          ]),
          const SizedBox(height: 4),
          Text('${r.categoryName} · ${when(r.preferredTime)}'),
          if (r.isEmergency) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.bolt, color: Colors.red, size: 18),
              Text(' Emergency · fee ${rs(r.emergencyFee)}'),
            ]),
          ],
          const SizedBox(height: 10),
          Text(r.description),
          const SizedBox(height: 8),
          Text('${r.address}${r.area.isNotEmpty ? ', ${r.area}' : ''}', style: theme.textTheme.bodySmall),
          if (r.budget != null) Text('Budget: ${rs(r.budget)}', style: theme.textTheme.bodySmall),
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final url in r.images)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(width: 80, child: Icon(Icons.broken_image)))),
                  ),
              ]),
            ),
          ],
          if (r.cancelReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Cancelled: ${r.cancelReason}', style: TextStyle(color: theme.colorScheme.error)),
          ],
        ]),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.requestOpen, required this.onAccept, required this.onCounter,
      required this.onReject});
  final WorkerOffer offer;
  final bool requestOpen;
  final VoidCallback onAccept;
  final VoidCallback onCounter;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final theme = Theme.of(context);
    final myTurn = o.isPending && requestOpen && o.awaiting == 'customer';
    return Card(
      key: Key('offer-${o.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WorkerSummary(
            worker: o.worker,
            onTap: () => context.push('/workers/${o.worker.id}'),
            trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rs(o.currentPrice), style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
              if (o.currentPrice != o.initialPrice)
                Text(rs(o.initialPrice), style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.timer, size: 16), Text(' ~${o.etaMinutes} min')]),
            if (o.distanceKm != null)
              Row(mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.place, size: 16), Text(' ${o.distanceKm!.toStringAsFixed(1)} km')]),
            if (!o.isPending) StatusChip(o.status),
          ]),
          if (o.message.isNotEmpty) ...[const SizedBox(height: 8), Text('"${o.message}"')],
          if (o.negotiations.length > 1) ...[
            const Divider(height: 20),
            NegotiationHistory(offer: o, viewerIsCustomer: true),
          ],
          if (o.isPending && requestOpen) ...[
            const SizedBox(height: 10),
            if (!myTurn)
              Text('Waiting for ${o.worker.fullName.split(' ').first} to respond to your counter offer.',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (myTurn)
                FilledButton.icon(
                  key: Key('accept-${o.id}'),
                  onPressed: onAccept,
                  icon: const Icon(Icons.check),
                  label: Text('Book for ${rs(o.currentPrice)}'),
                ),
              if (myTurn)
                OutlinedButton.icon(
                  key: Key('counter-${o.id}'),
                  onPressed: onCounter,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Counter'),
                ),
              TextButton(onPressed: onReject, child: const Text('Reject')),
            ]),
          ],
        ]),
      ),
    );
  }
}
