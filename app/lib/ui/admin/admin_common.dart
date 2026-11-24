import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/admin_api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

AdminApi adminApi(BuildContext context) => AdminApi(context.read<Session>().api.client);

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.icon, this.color, this.onTap});
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 210,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (icon != null) Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
                if (icon != null) const SizedBox(width: 6),
                Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              ]),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Simple vertical bar chart (no chart package needed).
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.points, this.height = 160, this.format});
  final List<(String, double)> points;
  final double height;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) return SizedBox(height: height, child: const Center(child: Text('No data yet')));
    final maxV = points.map((p) => p.$2).fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height + 36,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (i, p) in points.indexed)
          Expanded(
            child: Tooltip(
              message: '${p.$1}: ${format?.call(p.$2) ?? p.$2.toStringAsFixed(0)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (points.length <= 12)
                    Text(format?.call(p.$2) ?? p.$2.toStringAsFixed(0), style: theme.textTheme.labelSmall, maxLines: 1),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 48),
                    height: maxV == 0 ? 2 : (p.$2 / maxV * height).clamp(2, height),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(points.length > 12 && i % 5 != 4 ? '' : p.$1,
                      style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.clip),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A paginated list with "Load more", reloadable from outside via its state.
class PagedList<T> extends StatefulWidget {
  const PagedList({super.key, required this.load, required this.itemBuilder, this.empty = 'Nothing here'});
  final Future<Paged<T>> Function(int page) load;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String empty;

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  int _page = 1;
  int _count = 0;
  bool _hasMore = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.load(1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.results);
        _page = 1;
        _count = p.count;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    try {
      final p = await widget.load(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.results);
        _page++;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) return ErrorView(error: _error!, onRetry: reload);
    if (_items.isEmpty) return EmptyView(icon: Icons.inbox_outlined, title: widget.empty);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('$_count total', style: Theme.of(context).textTheme.bodySmall),
            );
          }
          if (i == _items.length + 1) {
            return _hasMore
                ? Center(child: TextButton(onPressed: _more, child: const Text('Load more')))
                : const SizedBox(height: 24);
          }
          return widget.itemBuilder(context, _items[i - 1], reload);
        },
      ),
    );
  }
}

/// A row of filter chips; `null` means "all".
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.selected, required this.onSelected});
  final List<(String?, String)> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(o.$2), selected: selected == o.$1, onSelected: (_) => onSelected(o.$1)),
            ),
        ]),
      );
}

String rsShort(Object? v) => rs('${v ?? 0}');
