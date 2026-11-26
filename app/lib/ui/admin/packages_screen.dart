import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// Workers' fixed-price packages, newest first. Hide anything misleading; the worker is told why.
class AdminPackagesScreen extends StatefulWidget {
  const AdminPackagesScreen({super.key});
  @override
  State<AdminPackagesScreen> createState() => _AdminPackagesScreenState();
}

class _AdminPackagesScreenState extends State<AdminPackagesScreen> {
  String? _hidden = 'false';
  final _list = GlobalKey<PagedListState<ServicePackage>>();

  Future<void> _toggle(ServicePackage p, VoidCallback reload) async {
    if (p.isHidden) {
      final r = await runAction(context, () => adminApi(context).unhidePackage(p.id), success: 'Package shown again.');
      if (r != null) reload();
      return;
    }
    final reason = await promptText(context, 'Hide this package?',
        label: 'Reason (the worker sees it)', ok: 'Hide', required: true);
    if (reason == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).hidePackage(p.id, reason.trim()),
        success: 'Package hidden. The worker was told why.');
    if (r != null) reload();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Service packages',
        body: Column(children: [
          FilterChips(
            options: const [('false', 'Shown'), ('true', 'Hidden'), (null, 'All')],
            selected: _hidden,
            onSelected: (v) {
              setState(() => _hidden = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<ServicePackage>(
              key: _list,
              empty: 'No packages',
              load: (page) => adminApi(context).packages(hidden: _hidden == null ? null : _hidden == 'true', page: page),
              itemBuilder: (context, p, reload) => Card(
                child: ListTile(
                  key: Key('admin-package-${p.id}'),
                  title: Text('${p.title} · ${rs(p.price)}'),
                  subtitle: Text([
                    p.workerName,
                    p.categoryName,
                    durationLabel(p.durationMinutes),
                    'Booked ${p.timesBooked}x',
                    if (!p.isActive) 'Paused',
                    if (p.isHidden) 'Hidden: ${p.hiddenReason}',
                    if (p.description.isNotEmpty) '\n${p.description}',
                  ].join(' · ')),
                  isThreeLine: p.description.isNotEmpty,
                  trailing: TextButton(
                    key: Key('admin-package-toggle-${p.id}'),
                    onPressed: () => _toggle(p, reload),
                    child: Text(p.isHidden ? 'Show' : 'Hide'),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}
