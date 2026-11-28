import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

/// The work guarantee on a completed booking.
///
/// Customer: ask for a free fix within the guarantee period, then follow the claim (withdraw,
/// confirm it is fixed, or send it to the KaamNow team). Worker: accept with a time to come back,
/// or decline with a reason, then mark the fix done.
class GuaranteePanel extends StatelessWidget {
  const GuaranteePanel({super.key, required this.booking, required this.isWorker, required this.onChanged});
  final Booking booking;
  final bool isWorker;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final g = booking.guarantee;
    final claim = g.claim;
    if (claim == null) {
      if (isWorker || !g.canClaim) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          key: const Key('guarantee-claim'),
          onPressed: () => _claim(context),
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(g.until == null
              ? context.t.problemCameBack
              : '${context.t.problemCameBack} · ${context.t.guaranteeUntil(day(g.until))}'),
        ),
      );
    }
    return _ClaimCard(claim: claim, isWorker: isWorker, onChanged: onChanged);
  }

  Future<void> _claim(BuildContext context) async {
    final api = context.read<Session>().api;
    final problem = await promptText(context, context.t.askFreeFix,
        message: context.t.askFreeFixHint, label: context.t.whatWentWrongAgain, ok: context.t.sendClaim, required: true);
    if (problem == null || !context.mounted) return;
    final c = await runAction(context, () => api.makeGuaranteeClaim(booking.id, problem),
        success: context.t.claimSent);
    if (c != null) onChanged();
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.isWorker, required this.onChanged});
  final GuaranteeClaim claim;
  final bool isWorker;
  final VoidCallback onChanged;

  String _status(BuildContext context) {
    final t = context.t;
    return switch (claim.status) {
      'pending' => isWorker ? t.claimAnswerBy(when(claim.respondBy)) : t.claimWaitingWorker,
      'accepted' => t.claimWorkerComing(when(claim.redoTime)),
      'declined' => t.claimDeclined,
      'redo_done' => t.claimRedoDone,
      'fixed' => t.claimFixed,
      'escalated' => t.claimEscalated,
      'withdrawn' => t.claimWithdrawn,
      _ => claim.status,
    };
  }

  Future<void> _run(BuildContext context, Future<Object?> Function() action, String success) async {
    final r = await runAction(context, action, success: success);
    if (r != null) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final api = context.read<Session>().api;
    final buttons = <Widget>[];
    if (isWorker) {
      if (claim.status == 'pending') {
        buttons.add(FilledButton(
          key: const Key('claim-accept'),
          onPressed: () async {
            final time = await showDialog<DateTime>(context: context, builder: (_) => const RedoTimeDialog());
            if (time == null || !context.mounted) return;
            await _run(context, () => api.acceptGuaranteeClaim(claim.id, time), t.claimAcceptedMsg);
          },
          child: Text(t.acceptAndPickTime),
        ));
        buttons.add(OutlinedButton(
          key: const Key('claim-decline'),
          onPressed: () async {
            final reason = await promptText(context, t.declineClaim,
                message: t.declineClaimHint, label: t.reason, ok: t.declineClaim, required: true);
            if (reason == null || !context.mounted) return;
            await _run(context, () => api.declineGuaranteeClaim(claim.id, reason), t.claimDeclinedMsg);
          },
          child: Text(t.declineClaim),
        ));
      } else if (claim.status == 'accepted') {
        buttons.add(FilledButton(
          key: const Key('claim-redo-done'),
          onPressed: () => _run(context, () => api.guaranteeRedoDone(claim.id), t.claimRedoDoneMsg),
          child: Text(t.markFixDone),
        ));
      }
    } else {
      if (claim.status == 'accepted' || claim.status == 'redo_done') {
        buttons.add(FilledButton(
          key: const Key('claim-confirm-fixed'),
          onPressed: () => _run(context, () => api.guaranteeConfirmFixed(claim.id), t.thanksConfirmed),
          child: Text(t.itsFixed),
        ));
      }
      if (claim.canEscalate) {
        buttons.add(OutlinedButton(
          key: const Key('claim-escalate'),
          onPressed: () async {
            final details = await promptText(context, t.sendToKaamNow,
                message: t.sendToKaamNowHint, label: t.anythingToAdd, ok: t.send);
            if (details == null || !context.mounted) return;
            await _run(context, () => api.escalateGuaranteeClaim(claim.id, details: details), t.claimEscalatedMsg);
          },
          child: Text(t.sendToKaamNow),
        ));
      }
      if (const {'pending', 'accepted', 'redo_done'}.contains(claim.status)) {
        buttons.add(TextButton(
          key: const Key('claim-withdraw'),
          onPressed: () async {
            if (!await confirm(context, t.withdrawClaimQ, t.withdrawClaimBody, ok: t.withdraw)) return;
            if (!context.mounted) return;
            await _run(context, () => api.withdrawGuaranteeClaim(claim.id), t.claimWithdrawnMsg);
          },
          child: Text(t.withdraw),
        ));
      }
    }
    return Card(
      key: const Key('guarantee-card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(t.guaranteeClaim, style: theme.textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text(_status(context), key: const Key('claim-status'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('${t.problem}: ${claim.problem}', style: theme.textTheme.bodySmall),
          if (claim.workerNote.isNotEmpty)
            Text('${t.workerSays}: ${claim.workerNote}', style: theme.textTheme.bodySmall),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        ]),
      ),
    );
  }
}

/// Lets the worker pick when to come back: one of the next 7 days and a time of day.
class RedoTimeDialog extends StatefulWidget {
  const RedoTimeDialog({super.key, this.now});
  final DateTime? now;
  @override
  State<RedoTimeDialog> createState() => _RedoTimeDialogState();
}

class _RedoTimeDialogState extends State<RedoTimeDialog> {
  static const hours = [9, 12, 15, 18];
  late final DateTime _now = widget.now ?? DateTime.now();
  int _day = 1;
  int _hour = 12;

  DateTime get _chosen {
    final d = DateTime(_now.year, _now.month, _now.day).add(Duration(days: _day));
    return DateTime(d.year, d.month, d.day, _hour);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final today = DateTime(_now.year, _now.month, _now.day);
    return AlertDialog(
      title: Text(t.whenComeBack),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < 7; i++)
              ChoiceChip(
                key: Key('redo-day-$i'),
                label: Text(i == 0 ? t.today : i == 1 ? t.tomorrow : day(today.add(Duration(days: i)))),
                selected: _day == i,
                onSelected: (_) => setState(() => _day = i),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final h in hours)
              ChoiceChip(
                key: Key('redo-hour-$h'),
                label: Text(clock(DateTime(2026, 1, 1, h))),
                selected: _hour == h,
                onSelected: (_) => setState(() => _hour = h),
              ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
          key: const Key('redo-ok'),
          onPressed: _chosen.isAfter(_now) ? () => Navigator.pop(context, _chosen) : null,
          child: Text(t.accept),
        ),
      ],
    );
  }
}
