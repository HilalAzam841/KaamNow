import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/level_widgets.dart';

/// The worker's level and badges, and what the next level still needs.
class LevelScreen extends StatelessWidget {
  const LevelScreen({super.key});

  String _requirement(BuildContext context, LevelRequirement r, int days) {
    final t = context.t;
    String n(String s) {
      final v = double.tryParse(s) ?? 0;
      return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    }

    String rating(String s) => (double.tryParse(s) ?? 0).toStringAsFixed(1);
    return switch (r.key) {
      'jobs' => t.reqJobs(n(r.value), n(r.target)),
      'rating' => t.reqRating(rating(r.value), rating(r.target)),
      'reviews' => t.reqReviews(n(r.value), n(r.target)),
      'no_shows' => t.reqNoShows(days, n(r.value), n(r.target)),
      'cancel_rate' => t.reqCancelRate(days, n(r.value), n(r.target)),
      _ => r.key,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(t.myLevel), actions: const [LanguageButton()]),
      body: PageBody(
        child: Loader<LevelProgress>(
          load: api.myLevel,
          builder: (context, p, reload) {
            final theme = Theme.of(context);
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.yourLevelIs, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Transform.scale(
                          scale: 1.3, alignment: AlignmentDirectional.centerStart, child: LevelChip(p.level, showNew: true)),
                      const SizedBox(height: 10),
                      Text(p.verified ? t.levelShownHint : t.levelNeedsVerification),
                    ]),
                  ),
                ),
                if (p.nextLevel == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(t.topLevelReached, key: const Key('top-level'), style: theme.textTheme.titleMedium),
                  )
                else if (p.verified) ...[
                  SectionTitle(t.nextLevelIs(levelLabel(context, p.nextLevel!))),
                  for (final r in p.requirements)
                    Padding(
                      key: Key('req-${r.key}'),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(r.met ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20, color: r.met ? Colors.green.shade700 : theme.colorScheme.outline),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_requirement(context, r, p.windowDays))),
                        ]),
                        if (!r.met && r.progress > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 28, top: 4),
                            child: LinearProgressIndicator(value: r.progress),
                          ),
                      ]),
                    ),
                ],
                SectionTitle(t.yourBadges),
                if (p.badges.isEmpty)
                  Text(t.noBadgesYet)
                else
                  BadgeRow(p.badges, skipVerified: false),
              ]),
            );
          },
        ),
      ),
    );
  }
}
