import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/package_widgets.dart';

const maxPackages = 10;
const packageDurations = [30, 60, 90, 120, 180, 240, 360, 480];

/// The worker's fixed-price packages: add, edit, pause and delete.
class MyPackagesScreen extends StatefulWidget {
  const MyPackagesScreen({super.key});
  @override
  State<MyPackagesScreen> createState() => _MyPackagesScreenState();
}

class _MyPackagesScreenState extends State<MyPackagesScreen> {
  final _loader = GlobalKey<LoaderState<(List<ServicePackage>, List<WorkerServiceInline>)>>();

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _edit(List<WorkerServiceInline> services, [ServicePackage? existing]) async {
    final saved = await Navigator.of(context).push<ServicePackage>(MaterialPageRoute(
      builder: (_) => PackageFormScreen(services: services, existing: existing),
    ));
    if (saved != null) await _reload();
  }

  Future<void> _togglePause(ServicePackage p) async {
    final t = context.t;
    final r = await runAction(context, () => context.read<Session>().api.updatePackage(p.id, {'is_active': !p.isActive}),
        success: p.isActive ? t.packagePaused : t.packageLive);
    if (r != null) await _reload();
  }

  Future<void> _delete(ServicePackage p) async {
    final t = context.t;
    if (!await confirm(context, t.deletePackageQ, t.deletePackageBody, ok: t.delete)) return;
    if (!mounted) return;
    final r = await runAction(context, () async {
      await context.read<Session>().api.deletePackage(p.id);
      return true;
    }, success: t.packageDeleted);
    if (r != null) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(t.myPackages), actions: const [LanguageButton()]),
      body: PageBody(
        child: Loader<(List<ServicePackage>, List<WorkerServiceInline>)>(
          key: _loader,
          load: () async => (await api.myPackages(), (await api.myWorkerProfile()).services),
          builder: (context, data, reload) {
            final (packages, allServices) = data;
            final services = allServices.where((s) => s.isActive).toList();
            final theme = Theme.of(context);
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text(t.packagesIntro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  Text(t.packagesNeedService, key: const Key('packages-need-service'))
                else if (packages.length < maxPackages)
                  FilledButton.icon(
                    key: const Key('package-add'),
                    onPressed: () => _edit(services),
                    icon: const Icon(Icons.add),
                    label: Text(t.addPackage),
                  )
                else
                  Text(t.packagesLimit(maxPackages), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                if (packages.isEmpty)
                  EmptyView(icon: Icons.sell_outlined, title: t.noPackagesYet)
                else
                  for (final p in packages)
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Opacity(opacity: p.isActive && !p.isHidden ? 1 : 0.6, child: PackageCard(package: p)),
                      if (p.isHidden)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(t.packageHiddenByAdmin(p.hiddenReason), key: Key('package-hidden-${p.id}'),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        ),
                      Row(children: [
                        Switch(
                          key: Key('package-active-${p.id}'),
                          value: p.isActive,
                          onChanged: (_) => _togglePause(p),
                        ),
                        Text(p.isActive ? t.packageShown : t.packagePausedLabel),
                        const Spacer(),
                        IconButton(
                          key: Key('package-edit-${p.id}'),
                          tooltip: t.edit,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(services, p),
                        ),
                        IconButton(
                          key: Key('package-delete-${p.id}'),
                          tooltip: t.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(p),
                        ),
                      ]),
                      const SizedBox(height: 8),
                    ]),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Add or change a package.
class PackageFormScreen extends StatefulWidget {
  const PackageFormScreen({super.key, required this.services, this.existing});
  final List<WorkerServiceInline> services;
  final ServicePackage? existing;
  @override
  State<PackageFormScreen> createState() => _PackageFormScreenState();
}

class _PackageFormScreenState extends State<PackageFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _price = TextEditingController(
      text: widget.existing == null ? '' : (double.tryParse(widget.existing!.price) ?? 0).round().toString());
  late final _includes = TextEditingController(text: widget.existing?.includes.join('\n') ?? '');
  late int? _category = widget.existing?.category ??
      (widget.services.length == 1 ? widget.services.first.category : null);
  late int _duration = widget.existing?.durationMinutes ?? 60;
  bool _busy = false;
  Map<String, String> _fieldErrors = {};

  Future<void> _save() async {
    final t = context.t;
    setState(() => _fieldErrors = {});
    if (!_form.currentState!.validate()) return;
    if (_category == null) return showInfo(context, t.chooseService);
    final fields = {
      'category': _category,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'price': _price.text.trim(),
      'duration_minutes': _duration,
      'includes': [for (final l in _includes.text.split('\n')) if (l.trim().isNotEmpty) l.trim()],
    };
    setState(() => _busy = true);
    try {
      final api = context.read<Session>().api;
      final saved = widget.existing == null
          ? await api.createPackage(fields)
          : await api.updatePackage(widget.existing!.id, fields);
      if (!mounted) return;
      showInfo(context, t.packageSaved);
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      setState(() => _fieldErrors = e.fieldErrors);
      _form.currentState!.validate();
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final durations = {...packageDurations, _duration}.toList()..sort();
    final categories = {for (final s in widget.services) s.category: s.categoryName};
    if (_category != null && !categories.containsKey(_category)) {
      categories[_category!] = widget.existing?.categoryName ?? '';
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? t.addPackage : t.editPackage)),
      body: PageBody(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<int>(
              key: const Key('package-category'),
              initialValue: _category,
              decoration: InputDecoration(labelText: t.service),
              items: [
                for (final e in categories.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('package-title'),
              controller: _title,
              maxLength: 80,
              decoration: InputDecoration(labelText: t.packageTitle, hintText: t.packageTitleHint),
              validator: (v) => _fieldErrors['title'] ?? ((v ?? '').trim().length < 3 ? t.titleTooShort : null),
            ),
            TextFormField(
              key: const Key('package-price'),
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.packagePrice, prefixText: 'Rs '),
              validator: (v) => _fieldErrors['price'] ?? ((double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? t.enterPrice : null),
            ),
            const SizedBox(height: 12),
            Text(t.packageDuration, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in durations)
                ChoiceChip(
                  key: Key('package-duration-$d'),
                  label: Text(durationLabel(d)),
                  selected: _duration == d,
                  onSelected: (_) => setState(() => _duration = d),
                ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('package-includes'),
              controller: _includes,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: t.packageIncludes, hintText: t.packageIncludesHint,
                  alignLabelWithHint: true),
              validator: (v) {
                if (_fieldErrors['includes'] != null) return _fieldErrors['includes'];
                final lines = (v ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
                if (lines.length > 8) return t.packageIncludesTooMany;
                if (lines.any((l) => l.trim().length > 80)) return t.packageIncludesTooLong;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('package-description'),
              controller: _description,
              minLines: 2,
              maxLines: 5,
              maxLength: 600,
              decoration: InputDecoration(labelText: t.packageDescription, alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            Text(t.packageFixedPriceNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('package-save'),
              onPressed: _busy ? null : _save,
              child: Text(t.save),
            ),
          ]),
        ),
      ),
    );
  }
}
