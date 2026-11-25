import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/kaamnow_api.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/offer_widgets.dart';
import '../../l10n/l10n.dart';

/// Worker view of a request: details, plus either an offer form or their existing offer.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.id});
  final int id;
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late final KaamNowApi api = context.read<Session>().api;
  ServiceRequest? _request;
  WorkerOffer? _offer;
  Object? _error;
  bool _loaded = false;

  final _form = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _eta = TextEditingController(text: '45');
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.request(widget.id);
      final offers = await api.offersForRequest(widget.id);
      if (!mounted) return;
      setState(() {
        _request = r;
        _offer = offers.results.isEmpty ? null : offers.results.first;
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _submitOffer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final o = await api.createOffer(widget.id,
          price: _price.text.trim(), etaMinutes: int.parse(_eta.text.trim()), message: _message.text.trim());
      if (!mounted) return;
      showInfo(context, context.t.offerSent);
      setState(() => _offer = o);
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _agree() async {
    final o = _offer!;
    if (!await confirm(context, context.t.agreeToQ(rs(o.currentPrice)), context.t.agreeToHint, ok: context.t.agree)) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () => api.negotiate(o.id, agree: true), success: context.t.youAgreed);
    _load();
  }

  Future<void> _counter() async {
    final r = await askCounter(context, _offer!.currentPrice);
    if (r == null || !mounted) return;
    await runAction(context, () => api.negotiate(_offer!.id, amount: r.$1, message: r.$2), success: context.t.counterSent);
    _load();
  }

  Future<void> _decline() async {
    final t = context.t;
    if (!await confirm(context, t.cannotTakeJobQ, t.cannotTakeJobHint, ok: t.cannotTakeJobOk)) return;
    if (!mounted) return;
    final ok = await runAction(context, () async {
      await api.declineRequest(_request!.id);
      return true;
    }, success: t.jobPassedOn);
    if (ok != true || !mounted) return;
    context.canPop() ? context.pop() : _load();
  }

  Future<void> _withdraw() async {
    if (!await confirm(context, context.t.withdrawOfferQ, context.t.withdrawHint, ok: context.t.withdraw)) return;
    if (!mounted) return;
    await runAction(context, () => api.rejectOffer(_offer!.id, reason: 'Withdrawn by worker'));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t.job), actions: const [LanguageButton()]),
      body: !_loaded
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : PageBody(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r!.title, style: theme.textTheme.titleLarge)),
                        StatusChip(r.status),
                      ]),
                      Text('${r.categoryName} · ${whenWindow(r.preferredTime, r.durationMinutes)}'),
                      if (r.isDirect)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.favorite, color: theme.colorScheme.primary, size: 18),
                            Text(' ${context.t.askedForYou}', key: const Key('asked-for-you')),
                          ]),
                        ),
                      if (r.isEmergency)
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Row(children: [Icon(Icons.bolt, color: Colors.red, size: 18), Text(' ${context.t.emergencyJob}')]),
                        ),
                      const SizedBox(height: 10),
                      Text(r.description),
                      const SizedBox(height: 8),
                      if (r.area.isNotEmpty) Text(context.t.areaLine(r.area), style: theme.textTheme.bodySmall),
                      if (r.budget != null) Text(context.t.customerBudget(rs(r.budget)), style: theme.textTheme.bodySmall),
                      Text(context.t.addressAfterBooking, style: theme.textTheme.bodySmall),
                      if (r.images.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, children: [
                          for (final url in r.images)
                            ClipRRect(borderRadius: BorderRadius.circular(8),
                                child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(width: 90, child: Icon(Icons.broken_image)))),
                        ]),
                      ],
                    ]),
                  ),
                ),
                if (_offer == null && r.isOpen) _offerForm(),
                if (_offer == null && r.isOpen && r.isDirect)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      key: const Key('decline-direct'),
                      onPressed: _decline,
                      icon: const Icon(Icons.do_not_disturb_alt),
                      label: Text(context.t.cannotTakeJob),
                    ),
                  ),
                if (_offer != null) _offerStatus(_offer!),
              ]),
            ),
    );
  }

  Widget _offerForm() {
    final min = context.read<Session>().config.minOfferPrice;
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(context.t.sendYourPrice),
        TextFormField(
          key: const Key('offer-price'),
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.t.yourPrice, prefixText: context.t.rsPrefix),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim());
            if (n == null) return context.t.enterPrice;
            final lo = double.tryParse(min) ?? 0;
            return n < lo ? context.t.minimumIs(rs(min)) : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('offer-eta'),
          controller: _eta,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.t.arriveInMinutes),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            return n == null || n < 1 ? context.t.enterMinutes : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('offer-message'),
          controller: _message,
          maxLines: 2,
          decoration: InputDecoration(labelText: context.t.messageToCustomer),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('offer-submit'),
          onPressed: _busy ? null : _submitOffer,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.t.sendOffer),
        ),
      ]),
    );
  }

  Widget _offerStatus(WorkerOffer o) {
    final theme = Theme.of(context);
    final myTurn = o.isPending && o.awaiting == 'worker';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(context.t.yourOffer),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(rs(o.currentPrice), style: theme.textTheme.headlineSmall)),
              StatusChip(o.status),
            ]),
            const SizedBox(height: 8),
            NegotiationHistory(offer: o, viewerIsCustomer: false),
            if (o.isPending) ...[
              const SizedBox(height: 12),
              Text(myTurn ? context.t.customerCounteredYourMove : context.t.waitingForCustomer,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (myTurn)
                  FilledButton(key: const Key('offer-agree'), onPressed: _agree, child: Text(context.t.agreeToAmount(rs(o.currentPrice)))),
                if (myTurn)
                  OutlinedButton(key: const Key('offer-counter'), onPressed: _counter, child: Text(context.t.counter)),
                TextButton(onPressed: _withdraw, child: Text(context.t.withdraw)),
              ]),
            ],
            if (o.bookingId != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/bookings/${o.bookingId}'),
                icon: const Icon(Icons.event_available),
                label: Text(context.t.openBooking),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}
