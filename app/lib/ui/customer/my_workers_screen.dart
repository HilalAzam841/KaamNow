import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/offer_widgets.dart';

/// Heart button that saves or removes a worker from the customer's favourites.
class FavouriteButton extends StatefulWidget {
  const FavouriteButton({super.key, required this.workerId, required this.initial, this.onChanged});
  final int workerId;
  final bool initial;
  final ValueChanged<bool>? onChanged;

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> {
  late bool _saved = widget.initial;
  bool _busy = false;

  @override
  void didUpdateWidget(FavouriteButton old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial) _saved = widget.initial;
  }

  Future<void> _toggle() async {
    final t = context.t;
    final api = context.read<Session>().api;
    final next = !_saved;
    setState(() => _busy = true);
    final ok = await runAction(context, () async {
      next ? await api.addFavourite(widget.workerId) : await api.removeFavourite(widget.workerId);
      return true;
    }, success: next ? t.workerSaved : t.workerUnsaved);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok == true) _saved = next;
    });
    if (ok == true) widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return IconButton(
      key: Key('favourite-${widget.workerId}'),
      tooltip: _saved ? t.removeFromFavourites : t.saveToFavourites,
      isSelected: _saved,
      onPressed: _busy ? null : _toggle,
      icon: const Icon(Icons.favorite_border),
      selectedIcon: const Icon(Icons.favorite, color: Colors.red),
    );
  }
}

/// Opens Post a job for this worker only.
void bookAgain(BuildContext context, PublicWorker w, {int? category}) {
  final services = w.activeServices;
  final cat = category ?? (services.length == 1 ? services.first.category : null);
  context.push('/requests/new?worker=${w.id}${cat == null ? '' : '&category=$cat'}');
}

/// Saved workers and workers who did a job for the customer before, to book again.
class MyWorkersScreen extends StatelessWidget {
  const MyWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.myWorkers)),
      body: PageBody(
        child: Loader<(List<PublicWorker>, List<PublicWorker>)>(
          load: () async => (await api.favourites(), await api.recentWorkers()),
          builder: (context, data, reload) {
            final (saved, recent) = data;
            final savedIds = {for (final w in saved) w.id};
            final others = recent.where((w) => !savedIds.contains(w.id)).toList();
            if (saved.isEmpty && others.isEmpty) {
              return EmptyView(icon: Icons.favorite_border, title: context.t.noWorkersYet, subtitle: context.t.noWorkersYetHint);
            }
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (saved.isNotEmpty) ...[
                  SectionTitle(context.t.savedWorkers),
                  for (final w in saved) _WorkerCard(worker: w, saved: true, onChanged: reload),
                ],
                if (others.isNotEmpty) ...[
                  SectionTitle(context.t.workedWithBefore),
                  for (final w in others) _WorkerCard(worker: w, saved: false, onChanged: reload),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker, required this.saved, required this.onChanged});
  final PublicWorker worker;
  final bool saved;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final t = context.t;
    return Card(
      key: Key('my-worker-${w.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WorkerSummary(
            worker: w,
            onTap: () => context.push('/workers/${w.id}'),
            trailing: FavouriteButton(workerId: w.id, initial: saved, onChanged: (_) => onChanged()),
          ),
          if (w.lastBookedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.lastBooked(day(w.lastBookedAt)), style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              key: Key('book-again-${w.id}'),
              onPressed: w.activeServices.isEmpty ? null : () => bookAgain(context, w),
              icon: const Icon(Icons.replay),
              label: Text(t.bookAgain),
            ),
          ),
        ]),
      ),
    );
  }
}
