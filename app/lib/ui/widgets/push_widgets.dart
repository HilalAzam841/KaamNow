import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/push/push_controller.dart';
import '../../core/push/push_platform.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import 'common.dart';

Future<void> _turnOn(BuildContext context) async {
  final push = context.read<PushController>();
  try {
    final ok = await push.enable();
    if (context.mounted) showInfo(context, ok ? context.t.pushTurnedOn : context.t.pushNotAllowed);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

/// "Get alerts on this device" card on the home screens, until turned on or dismissed.
class PushBanner extends StatelessWidget {
  const PushBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final push = context.watch<PushController>();
    if (!push.showBanner) return const SizedBox.shrink();
    final isWorker = context.watch<Session>().user?.isWorker ?? false;
    final theme = Theme.of(context);
    return Card(
      key: const Key('push-banner'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.notifications_active_outlined, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t.pushTitle, style: theme.textTheme.titleMedium),
                Text(isWorker ? context.t.pushHintWorker : context.t.pushHintCustomer),
              ]),
            ),
          ]),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(spacing: 8, children: [
              TextButton(key: const Key('push-dismiss'), onPressed: push.dismissBanner, child: Text(context.t.notNow)),
              FilledButton(
                key: const Key('push-enable'),
                onPressed: push.busy ? null : () => _turnOn(context),
                child: Text(context.t.turnOn),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Account screen switch for this device's notifications.
class PushTile extends StatelessWidget {
  const PushTile({super.key});

  @override
  Widget build(BuildContext context) {
    final push = context.watch<PushController>();
    final state = push.state;
    if (state == PushState.unavailable) return const SizedBox.shrink();
    final t = context.t;
    final subtitle = switch (state) {
      PushState.on => t.pushOnHint,
      PushState.blocked => push.platform.kind == PushKind.firebase ? t.pushBlockedHintPhone : t.pushBlockedHint,
      PushState.needsInstall => t.pushNeedsInstallHint,
      _ => t.pushOffHint,
    };
    return SwitchListTile(
      key: const Key('push-switch'),
      secondary: Icon(state == PushState.on ? Icons.notifications_active : Icons.notifications_off_outlined),
      title: Text(t.pushSetting),
      subtitle: Text(subtitle),
      value: state == PushState.on,
      onChanged: push.busy || state == PushState.blocked || state == PushState.needsInstall
          ? null
          : (on) async {
              if (on) {
                await _turnOn(context);
              } else {
                try {
                  await push.disable();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }
            },
    );
  }
}
