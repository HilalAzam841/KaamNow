import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

/// Open requests near the worker that match their services. Emergencies come first.
class JobFeedScreen extends StatelessWidget {
  const JobFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs near you')),
      body: Loader<(WorkerProfile, Paged<ServiceRequest>)>(
        load: () async => (await api.myWorkerProfile(), await api.requests(scope: 'feed')),
        builder: (context, data, reload) {
          final (profile, page) = data;
          return RefreshIndicator(
            onRefresh: reload,
            child: PageBody(
              child: ListView(padding: const EdgeInsets.all(12), children: [
                _ReadinessBanner(profile: profile, onChanged: reload),
                if (page.results.isEmpty)
                  EmptyView(
                    icon: Icons.work_outline,
                    title: 'No open jobs right now',
                    subtitle: profile.isVerified && profile.isAvailable
                        ? 'New jobs in your area and services will show up here, and you will get an alert.'
                        : null,
                  ),
                for (final r in page.results)
                  Card(
                    key: Key('job-${r.id}'),
                    child: ListTile(
                      leading: r.isEmergency
                          ? const Tooltip(message: 'Emergency', child: Icon(Icons.bolt, color: Colors.red))
                          : const Icon(Icons.work),
                      title: Text(r.title),
                      subtitle: Text('${r.categoryName}${r.area.isNotEmpty ? ' · ${r.area}' : ''}\n'
                          '${when(r.preferredTime)}${r.budget != null ? ' · budget ${rs(r.budget)}' : ''}'),
                      isThreeLine: true,
                      trailing: Text('${r.offersCount} offer${r.offersCount == 1 ? '' : 's'}'),
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
          title: Text(rejected ? 'Verification was rejected' : 'Get verified to send offers'),
          subtitle: Text(rejected
              ? (profile.rejectionReason.isEmpty ? 'Update your documents and try again.' : profile.rejectionReason)
              : 'Upload both sides of your CNIC, add your services and set your base location. '
                  'KaamNow reviews new workers before they can bid.'),
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
        title: Text(profile.isAvailable ? 'You are available for jobs' : 'You are offline'),
        subtitle: const Text('Only available workers get new job alerts.'),
        onChanged: (v) async {
          await runAction(context, () => context.read<Session>().api.setAvailability(v));
          onChanged();
        },
      ),
    );
  }
}
