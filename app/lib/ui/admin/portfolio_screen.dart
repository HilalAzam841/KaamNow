import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../worker/portfolio_screen.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// Workers' portfolio photos, newest first. Hide anything that is not suitable; the worker is told why.
class AdminPortfolioScreen extends StatefulWidget {
  const AdminPortfolioScreen({super.key});
  @override
  State<AdminPortfolioScreen> createState() => _AdminPortfolioScreenState();
}

class _AdminPortfolioScreenState extends State<AdminPortfolioScreen> {
  String? _hidden = 'false';
  final _list = GlobalKey<PagedListState<PortfolioPhoto>>();

  Future<void> _toggle(PortfolioPhoto p, VoidCallback reload) async {
    if (p.isHidden) {
      final r = await runAction(context, () => adminApi(context).unhidePortfolioPhoto(p.id), success: 'Photo shown again.');
      if (r != null) reload();
      return;
    }
    final reason = await promptText(context, 'Hide this photo?',
        label: 'Reason (the worker sees it)', ok: 'Hide', required: true);
    if (reason == null || !mounted) return;
    final r = await runAction(context, () => adminApi(context).hidePortfolioPhoto(p.id, reason.trim()),
        success: 'Photo hidden. The worker was told why.');
    if (r != null) reload();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Portfolio photos',
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
            child: PagedList<PortfolioPhoto>(
              key: _list,
              empty: 'No photos',
              load: (page) => adminApi(context).portfolioPhotos(hidden: _hidden == null ? null : _hidden == 'true', page: page),
              itemBuilder: (context, p, reload) => Card(
                child: ListTile(
                  key: Key('admin-photo-${p.id}'),
                  leading: PhotoTile(photo: p, size: 56, onTap: () => openPhoto(context, p)),
                  title: Text('${p.workerName}${p.caption.isEmpty ? '' : ' · ${p.caption}'}'),
                  subtitle: Text([
                    if (p.categoryName != null) p.categoryName!,
                    when(p.createdAt),
                    if (p.isHidden) 'Hidden: ${p.hiddenReason}',
                  ].join(' · ')),
                  trailing: TextButton(
                    key: Key('admin-photo-toggle-${p.id}'),
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
