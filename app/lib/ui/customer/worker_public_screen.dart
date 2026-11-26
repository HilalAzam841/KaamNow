import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../worker/portfolio_screen.dart';
import '../widgets/language_button.dart';
import '../widgets/offer_widgets.dart';
import '../worker/schedule_screen.dart' show hoursSummary;
import 'my_workers_screen.dart';
import '../../l10n/l10n.dart';
import '../widgets/level_widgets.dart';
import '../widgets/package_widgets.dart';
import 'package:go_router/go_router.dart';

class WorkerPublicScreen extends StatelessWidget {
  const WorkerPublicScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.workerProfile), actions: const [LanguageButton()]),
      body: Loader<(PublicWorker, Paged<Review>, List<ServicePackage>)>(
        load: () async => (
          await api.worker(id),
          await api.workerReviews(id),
          // Packages are extra: the profile still opens if they fail to load.
          await api.workerPackages(id).catchError((_) => <ServicePackage>[]),
        ),
        builder: (context, data, reload) {
          final (w, reviews, packages) = data;
          final theme = Theme.of(context);
          final isCustomer = context.read<Session>().user?.isCustomer == true;
          return PageBody(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              WorkerSummary(
                worker: w,
                trailing: isCustomer ? FavouriteButton(workerId: w.id, initial: w.isFavourite) : null,
              ),
              if (w.badges.any((b) => b != 'verified')) ...[const SizedBox(height: 8), BadgeRow(w.badges)],
              if (isCustomer && w.activeServices.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('worker-book'),
                  onPressed: () => bookAgain(context, w),
                  icon: const Icon(Icons.event_available),
                  label: Text(context.t.bookThisWorker),
                ),
              ],
              if (packages.isNotEmpty) ...[
                SectionTitle(context.t.fixedPricePackages),
                for (final p in packages)
                  PackageCard(
                    package: p,
                    onBook: isCustomer ? () => context.push('/packages/${p.id}/book') : null,
                  ),
              ],
              if (w.bio.isNotEmpty) ...[const SizedBox(height: 16), Text(w.bio)],
              if (w.portfolio.isNotEmpty) ...[
                SectionTitle(context.t.pastWork),
                PortfolioStrip(photos: w.portfolio),
              ],
              if (w.serviceArea.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.map, size: 16), Text(' ${context.t.worksIn(w.serviceArea)}')]),
              ],
              SectionTitle(context.t.services),
              for (final s in w.services.where((s) => s.isActive))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.categoryName),
                  subtitle: s.description.isEmpty ? null : Text(s.description),
                  trailing: s.startingPrice == null ? null : Text(context.t.fromPrice(rs(s.startingPrice))),
                ),
              SectionTitle(context.t.workingHours),
              if (w.workingHours.isEmpty)
                Text(context.t.availableAnyTime, key: const Key('worker-hours-any'))
              else
                for (final line in hoursSummary(context, w.workingHours)) Text(line),
              SectionTitle(context.t.reviewsHeading(reviews.count)),
              if (reviews.results.isEmpty) Text(context.t.noReviewsYet),
              for (final r in reviews.results)
                Card(
                  child: ListTile(
                    title: Row(children: [
                      for (var i = 0; i < 5; i++)
                        Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(r.customerName, style: theme.textTheme.bodySmall),
                    ]),
                    subtitle: Text([if (r.comment.isNotEmpty) r.comment, '${r.categoryName} · ${day(r.createdAt)}'].join('\n')),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
