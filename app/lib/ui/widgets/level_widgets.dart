import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

String levelLabel(BuildContext context, String level) => switch (level) {
      'rising' => context.t.levelRising,
      'trusted' => context.t.levelTrusted,
      'top_rated' => context.t.levelTopRated,
      _ => context.t.levelNew,
    };

String badgeLabel(BuildContext context, String badge) => switch (badge) {
      'verified' => context.t.badgeVerified,
      'jobs_100' => context.t.badgeJobs100,
      'experienced' => context.t.badgeExperienced,
      'customer_favourite' => context.t.badgeCustomerFavourite,
      'always_on_time' => context.t.badgeAlwaysOnTime,
      _ => badge,
    };

IconData badgeIcon(String badge) => switch (badge) {
      'verified' => Icons.verified,
      'jobs_100' => Icons.workspace_premium,
      'experienced' => Icons.handyman,
      'customer_favourite' => Icons.favorite,
      'always_on_time' => Icons.schedule,
      _ => Icons.star,
    };

/// A small coloured pill with the worker's level. Nothing for new workers.
class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key, this.showNew = false});
  final String level;
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    if (level == 'new' && !showNew) return const SizedBox.shrink();
    final (bg, fg, icon) = switch (level) {
      'top_rated' => (Colors.amber.shade100, Colors.brown.shade800, Icons.emoji_events),
      'trusted' => (Colors.blue.shade50, Colors.blue.shade900, Icons.shield),
      'rising' => (Colors.green.shade50, Colors.green.shade900, Icons.trending_up),
      _ => (Colors.grey.shade200, Colors.grey.shade800, Icons.fiber_new),
    };
    return Tooltip(
      message: context.t.levelHelp,
      child: Container(
        key: Key('level-$level'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(levelLabel(context, level), style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// The worker's badges as outlined chips. Verified is left out where a tick already shows it.
class BadgeRow extends StatelessWidget {
  const BadgeRow(this.badges, {super.key, this.skipVerified = true});
  final List<String> badges;
  final bool skipVerified;

  @override
  Widget build(BuildContext context) {
    final shown = [for (final b in badges) if (!(skipVerified && b == 'verified')) b];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final b in shown)
        Chip(
          key: Key('badge-$b'),
          avatar: Icon(badgeIcon(b), size: 16),
          label: Text(badgeLabel(context, b)),
          visualDensity: VisualDensity.compact,
        ),
    ]);
  }
}
