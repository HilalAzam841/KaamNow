import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/install_widgets.dart';
import '../widgets/push_widgets.dart';
import '../widgets/language_button.dart';
import '../../l10n/l10n.dart';

/// Open requests near the worker that match their services. Emergencies come first.
class JobFeedScreen extends StatelessWidget {
  const JobFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.jobsNearYou), actions: const [LanguageButton()]),
      body: Loader<(WorkerProfile, Paged<ServiceRequest>)>(
        load: () async => (await api.myWorkerProfile(), await api.requests(scope: 'feed')),
        builder: (context, data, reload) {
          final (profile, page) = data;
          return RefreshIndicator(
            onRefresh: reload,
            child: PageBody(
              child: ListView(padding: const EdgeInsets.all(12), children: [
                const PushBanner(),
                const InstallBanner(),
                _ReadinessBanner(profile: profile, onChanged: reload),
                if (page.results.isEmpty)
                  EmptyView(
                    icon: Icons.work_outline,
                    title: context.t.noOpenJobs,
                    subtitle: profile.isVerified && profile.isAvailable
                        ? context.t.noOpenJobsHint
                        : null,
                  ),
                for (final r in page.results)
                  Card(
                    key: Key('job-${r.id}'),
                    child: ListTile(
                      leading: r.isEmergency
                          ? Tooltip(message: context.t.emergency, child: Icon(Icons.bolt, color: Colors.red))
                          : const Icon(Icons.work),
                      title: Text(r.title),
                      subtitle: Text('${r.categoryName}${r.area.isNotEmpty ? ' · ${r.area}' : ''}\n'
                          '${whenWindow(r.preferredTime, r.durationMinutes)}${r.budget != null ? ' · ${context.t.budgetLower(rs(r.budget))}' : ''}'),
                      isThreeLine: true,
                      trailing: Text(context.t.offersCount(r.offersCount)),
                      onTap: () async {
                        await context.push('/jobs/${r.id}');
                        reload();
                      },
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  const _ReadinessBanner({required this.profile, required this.onChanged});
  final WorkerProfile profile;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!profile.isVerified) {
      final rejected = profile.verificationStatus == 'rejected';
      return Card(
        color: rejected ? theme.colorScheme.errorContainer : theme.colorScheme.tertiaryContainer,
        child: ListTile(
          leading: Icon(rejected ? Icons.error : Icons.verified_user_outlined),
          title: Text(rejected ? context.t.verificationRejected : context.t.getVerified),
          subtitle: Text(rejected
              ? (profile.rejectionReason.isEmpty ? context.t.updateDocsTryAgain : profile.rejectionReason)
              : context.t.getVerifiedHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await context.push('/worker/profile');
            onChanged();
          },
        ),
      );
    }
    return Card(
      child: SwitchListTile(
        key: const Key('availability'),
        value: profile.isAvailable,
        title: Text(profile.isAvailable ? context.t.youAreAvailable : context.t.youAreOffline),
        subtitle: Text(context.t.onlyAvailableGetAlerts),
        onChanged: (v) async {
          await runAction(context, () => context.read<Session>().api.setAvailability(v));
          onChanged();
        },
      ),
    );
  }
}
