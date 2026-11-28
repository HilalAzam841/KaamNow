import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/kaamnow_api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/offer_widgets.dart';
import '../../l10n/l10n.dart';

Map<String, String> _sortOptions(AppLocalizations t) => {
      'price': t.sortLowestPrice,
      'rating': t.sortHighestRating,
      'distance': t.sortNearest,
      'eta': t.sortFastest,
      'completed_jobs': t.sortMostJobs,
      'experience': t.sortMostExperience,
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
    final t = context.t;
    final ok = await confirm(context, t.bookWorkerQ(o.worker.fullName),
        _request!.isEmergency
            ? t.bookAgreeEmergency(rs(o.currentPrice), rs(_request!.emergencyFee))
            : t.bookAgree(rs(o.currentPrice)),
        ok: t.book);
    if (!ok || !mounted) return;
    final booking = await runAction(context, () => api.acceptOffer(o.id), success: context.t.booked);
    if (booking != null && mounted) context.pushReplacement('/bookings/${booking.id}');
  }

  Future<void> _counter(WorkerOffer o) async {
    final r = await askCounter(context, o.currentPrice);
    if (r == null || !mounted) return;
    await runAction(context, () => api.negotiate(o.id, amount: r.$1, message: r.$2), success: context.t.counterSent);
    _load();
  }

  Future<void> _reject(WorkerOffer o) async {
    final reason = await promptText(context, context.t.rejectOfferQ, label: context.t.reasonOptional, ok: context.t.reject);
    if (reason == null || !mounted) return;
    await runAction(context, () => api.rejectOffer(o.id, reason: reason));
    _load();
  }

  Future<void> _cancelRequest() async {
    final reason = await promptText(context, context.t.cancelRequestQ, label: context.t.reason, ok: context.t.cancelRequest, required: true);
    if (reason == null || !mounted) return;
    await runAction(context, () => api.cancelRequest(widget.id, reason), success: context.t.requestCancelled);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.request),
        actions: [
          if (r != null && r.isOpen)
            IconButton(tooltip: context.t.cancelRequest, onPressed: _cancelRequest, icon: const Icon(Icons.cancel_outlined)),
          const LanguageButton(),
        ],
      ),
      body: r == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: PageBody(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  _RequestHeader(request: r),
                  if (r.invitedWorkerId != null && r.isOpen)
                    Card(
                      key: const Key('invited-banner'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(context.t.sentOnlyTo(r.invitedWorkerName)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('open-to-all'),
                            onPressed: () async {
                              final api = context.read<Session>().api;
                              final updated = await runAction(context, () => api.openToAll(r.id));
                              if (updated != null && context.mounted) {
                                final n = updated.matchedWorkersCount ?? 0;
                                showInfo(context, n == 0 ? context.t.jobPostedNoWorkers : context.t.jobPostedNotified(n));
                                _load();
                              }
                            },
                            icon: const Icon(Icons.groups),
                            label: Text(context.t.sendToEveryone),
                          ),
                        ]),
                      ),
                    ),
                  if (r.bookingId != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: Text(context.t.jobIsBooked),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/bookings/${r.bookingId}'),
                      ),
                    ),
                  SectionTitle(
                    context.t.offersHeading(_offers.length),
                    trailing: _offers.length > 1
                        ? DropdownButton<String>(
                            value: _sort,
                            underline: const SizedBox(),
                            items: [for (final e in _sortOptions(context.t).entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
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
                      title: r.isOpen ? context.t.waitingForOffers : context.t.noOffers,
                      subtitle: r.isOpen ? context.t.waitingForOffersHint : null,
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
          Text('${r.categoryName} · ${whenWindow(r.preferredTime, r.durationMinutes)}'),
          if (r.isEmergency) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.bolt, color: Colors.red, size: 18),
              Text(' ${context.t.emergencyFee(rs(r.emergencyFee))}'),
            ]),
          ],
          const SizedBox(height: 10),
          Text(r.description),
          const SizedBox(height: 8),
          Text('${r.address}${r.area.isNotEmpty ? ', ${r.area}' : ''}', style: theme.textTheme.bodySmall),
          if (r.budget != null) Text(context.t.budget(rs(r.budget)), style: theme.textTheme.bodySmall),
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final url in r.images)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(width: 80, child: Icon(Icons.broken_image)))),
                  ),
              ]),
            ),
          ],
          if (r.cancelReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(context.t.cancelledReason(r.cancelReason), style: TextStyle(color: theme.colorScheme.error)),
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
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.timer, size: 16), Text(' ${context.t.etaMinutes(o.etaMinutes)}')]),
            if (o.distanceKm != null)
              Row(mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.place, size: 16), Text(' ${context.t.distanceKm(o.distanceKm!.toStringAsFixed(1))}')]),
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
              Text(context.t.waitingForCounter(o.worker.fullName.split(' ').first),
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (myTurn)
                FilledButton.icon(
                  key: Key('accept-${o.id}'),
                  onPressed: onAccept,
                  icon: const Icon(Icons.check),
                  label: Text(context.t.bookFor(rs(o.currentPrice))),
                ),
              if (myTurn)
                OutlinedButton.icon(
                  key: Key('counter-${o.id}'),
                  onPressed: onCounter,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(context.t.counter),
                ),
              TextButton(onPressed: onReject, child: Text(context.t.reject)),
            ]),
          ],
        ]),
      ),
    );
  }
}
