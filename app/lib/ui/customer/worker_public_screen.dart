import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/offer_widgets.dart';
import '../../l10n/l10n.dart';

class WorkerPublicScreen extends StatelessWidget {
  const WorkerPublicScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.workerProfile)),
      body: Loader<(PublicWorker, Paged<Review>)>(
        load: () async => (await api.worker(id), await api.workerReviews(id)),
        builder: (context, data, reload) {
          final (w, reviews) = data;
          final theme = Theme.of(context);
          return PageBody(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              WorkerSummary(worker: w),
              if (w.bio.isNotEmpty) ...[const SizedBox(height: 16), Text(w.bio)],
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
