import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/install/install_controller.dart';
import '../../l10n/l10n.dart';
import 'common.dart';

/// Installs the app, or on iPhone explains how to add it to the home screen.
Future<void> installApp(BuildContext context) async {
  final install = context.read<InstallController>();
  if (install.canInstall) {
    final accepted = await install.install();
    if (accepted && context.mounted) showInfo(context, context.t.installedThanks);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.ios_share),
      title: Text(c.t.howToInstall),
      content: Text(c.t.iosInstallSteps),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(c.t.ok))],
    ),
  );
}

/// "Install KaamNow" card shown at the top of the home screens until installed or dismissed.
class InstallBanner extends StatelessWidget {
  const InstallBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final install = context.watch<InstallController>();
    if (!install.showBanner) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const Key('install-banner'),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.install_mobile, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t.installTitle, style: theme.textTheme.titleMedium),
                Text(install.canInstall ? context.t.installHint : context.t.iosInstallSteps),
              ]),
            ),
          ]),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(spacing: 8, children: [
              TextButton(key: const Key('install-dismiss'), onPressed: install.dismissBanner, child: Text(context.t.notNow)),
              if (install.canInstall)
                FilledButton(
                    key: const Key('install-now'), onPressed: () => installApp(context), child: Text(context.t.install)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Account screen row; hidden when already installed or the browser cannot install.
class InstallTile extends StatelessWidget {
  const InstallTile({super.key});

  @override
  Widget build(BuildContext context) {
    final install = context.watch<InstallController>();
    if (!install.offerInstall) return const SizedBox.shrink();
    return ListTile(
      key: const Key('install-tile'),
      leading: const Icon(Icons.install_mobile),
      title: Text(context.t.installApp),
      subtitle: Text(context.t.installHint),
      onTap: () => installApp(context),
    );
  }
}
