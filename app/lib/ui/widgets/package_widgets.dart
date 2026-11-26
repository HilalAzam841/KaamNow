import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import 'common.dart';
import 'level_widgets.dart';

/// A fixed-price package: what it covers, its price and how long it takes.
///
/// Customers get a Book button. [showWorker] adds the worker's name, level and rating (on browse lists).
class PackageCard extends StatelessWidget {
  const PackageCard({super.key, required this.package, this.showWorker = false, this.onBook, this.trailing});
  final ServicePackage package;
  final bool showWorker;
  final VoidCallback? onBook;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final p = package;
    final w = p.worker;
    return Card(
      key: Key('package-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('${p.categoryName} · ${durationLabel(p.durationMinutes)}', style: theme.textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 8),
            Text(rs(p.price), key: Key('package-price-${p.id}'),
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            ?trailing,
          ]),
          if (p.description.isNotEmpty) ...[const SizedBox(height: 8), Text(p.description)],
          if (p.includes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in p.includes)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(line)),
                ]),
              ),
          ],
          if (showWorker && w != null) ...[
            const Divider(height: 20),
            InkWell(
              onTap: () => context.push('/workers/${w.id}'),
              child: Row(children: [
                Avatar(name: w.fullName, url: w.profilePicture, radius: 16),
                const SizedBox(width: 8),
                Flexible(child: Text(w.fullName, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                LevelChip(w.level),
                const Spacer(),
                RatingLine(rating: w.averageRating, count: w.ratingCount),
              ]),
            ),
          ],
          if (onBook != null || p.timesBooked > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (p.timesBooked > 0)
                Expanded(child: Text(t.packageBookedTimes(p.timesBooked), style: theme.textTheme.bodySmall))
              else
                const Spacer(),
              if (onBook != null)
                FilledButton.icon(
                  key: Key('package-book-${p.id}'),
                  onPressed: onBook,
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: Text(t.bookPackage),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
