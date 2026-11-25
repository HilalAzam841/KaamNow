import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

String creditKindLabel(BuildContext context, String kind) => switch (kind) {
  'welcome' => context.t.creditWelcome,
  'referral' => context.t.creditReferral,
  'spent' => context.t.creditSpent,
  'returned' => context.t.creditReturned,
  'admin' => context.t.creditAdmin,
  _ => humanize(kind),
};

/// The user's invite code to share, what they earn, and their credit.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t.inviteFriends)),
      body: PageBody(
        child: Loader<ReferralSummary>(
          load: session.api.referralSummary,
          builder: (context, r, reload) => _InviteBody(summary: r, isWorker: session.user?.isWorker == true),
        ),
      ),
    );
  }
}

class _InviteBody extends StatelessWidget {
  const _InviteBody({required this.summary, required this.isWorker});
  final ReferralSummary summary;
  final bool isWorker;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final r = summary;
    final message = t.inviteMessage(r.code, rs(r.welcomeCredit), r.inviteLink);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.yourInviteCode, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                SelectableText(
                  r.code,
                  key: const Key('invite-code'),
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  isWorker
                      ? t.inviteExplainWorker(rs(r.welcomeCredit), rs(r.minBooking), rs(r.referralReward))
                      : t.inviteExplain(rs(r.welcomeCredit), rs(r.minBooking), rs(r.referralReward)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('invite-copy'),
                  icon: const Icon(Icons.copy),
                  label: Text(t.copyInvite),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: message));
                    if (context.mounted) showInfo(context, t.inviteCopied);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.group_add_outlined),
          title: Text(t.invitedCount(r.invited)),
          subtitle: Text(t.rewardsEarned(rs(r.rewardsEarned))),
        ),
        if (!isWorker)
          ListTile(
            key: const Key('credit-balance'),
            leading: const Icon(Icons.savings_outlined),
            title: Text(t.creditBalance(rs(r.creditBalance))),
          ),
        if (r.creditHistory.isNotEmpty) ...[
          SectionTitle(t.creditHistory),
          for (final e in r.creditHistory)
            ListTile(
              key: Key('credit-${e.id}'),
              dense: true,
              title: Text(creditKindLabel(context, e.kind)),
              subtitle: Text([day(e.createdAt), if (e.note.isNotEmpty) e.note].join(' · ')),
              trailing: Text(
                '${e.amount.startsWith('-') ? '−' : '+'}${rs(e.amount.replaceFirst('-', ''))}',
                style: TextStyle(color: e.amount.startsWith('-') ? theme.colorScheme.error : Colors.green.shade700),
              ),
            ),
        ],
      ],
    );
  }
}
