import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/package_widgets.dart';
import 'addresses_screen.dart';

/// Fixed-price packages to book straight away, best workers first.
///
/// When the customer has a default saved address, only workers who cover it are shown.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key, this.categoryId});
  final int? categoryId;
  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  late int? _category = widget.categoryId;
  List<ServiceCategory> _categories = [];
  SavedAddress? _near;
  bool _ready = false;
  final List<ServicePackage> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  Object? _error;
  int _call = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = context.read<Session>();
    final api = session.api;
    try {
      _categories = await api.categories();
    } catch (_) {}
    if (session.user?.isCustomer == true) {
      try {
        final list = await api.savedAddresses();
        _near = list.where((a) => a.isDefault).firstOrNull;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final call = ++_call;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _items.clear();
    });
    try {
      final p = await context.read<Session>().api.packages(
          category: _category, lat: _near?.latitude, lng: _near?.longitude, page: page);
      if (!mounted || call != _call) return;
      setState(() {
        _items.addAll(p.results);
        _page = page;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      if (mounted && call == _call) setState(() => _error = e);
    } finally {
      if (mounted && call == _call) setState(() => _loading = false);
    }
  }

  void _choose(int? category) {
    setState(() => _category = category);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isCustomer = context.watch<Session>().user?.isCustomer == true;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.fixedPricePackages), actions: const [LanguageButton()]),
      body: PageBody(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text(t.packagesBrowseIntro),
                  if (_near != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t.packagesNear(addressTitle(context, _near!)), key: const Key('packages-near'),
                          style: theme.textTheme.bodySmall),
                    ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: const Key('packages-cat-all'),
                          label: Text(t.allServices),
                          selected: _category == null,
                          onSelected: (_) => _choose(null),
                        ),
                      ),
                      for (final c in _categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('packages-cat-${c.id}'),
                            label: Text(c.name),
                            selected: _category == c.id,
                            onSelected: (_) => _choose(c.id),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null && _items.isEmpty)
                    ErrorView(error: _error!, onRetry: () => _load(reset: true))
                  else if (!_loading && _items.isEmpty)
                    EmptyView(icon: Icons.sell_outlined, title: t.noPackagesFound, subtitle: t.noPackagesFoundHint)
                  else
                    for (final p in _items)
                      PackageCard(
                        package: p,
                        showWorker: true,
                        onBook: isCustomer ? () => context.push('/packages/${p.id}/book') : null,
                      ),
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  else if (_hasMore)
                    TextButton(key: const Key('packages-more'), onPressed: _load, child: Text(t.showMore)),
                ]),
              ),
      ),
    );
  }
}
