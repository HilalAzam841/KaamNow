import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../l10n/l10n.dart';

/// Loads data once (and on pull-to-refresh), showing spinner / error / content.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.empty, this.errorBuilder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final bool Function(T data)? empty;

  /// Replaces the default error view (with its Retry button) when loading fails.
  final Widget Function(BuildContext context, Object error, Future<void> Function() retry)? errorBuilder;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await widget.load();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return widget.errorBuilder?.call(context, _error!, reload) ?? ErrorView(error: _error!, onRetry: reload);
    }
    return widget.builder(context, _data as T, reload);
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException ? (error as ApiException).displayMessage : context.t.somethingWentWrong;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.t.tryAgain)),
          ],
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

/// Centers content and caps its width so pages read well on wide browser windows.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      'completed' || 'accepted' || 'verified' || 'resolved' || 'active' || 'approved' => (Colors.green.shade100, Colors.green.shade900),
      'cancelled' || 'rejected' || 'withdrawn' || 'failed' || 'expired' || 'disputed' => (Colors.red.shade100, Colors.red.shade900),
      'open' || 'pending' || 'confirmed' || 'in_review' || 'pending_payment' => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label ?? statusLabel(status),
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.rating, required this.count});
  final String rating;
  final int count;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
        const SizedBox(width: 2),
        Text(count == 0 ? context.t.ratingNew : '${double.tryParse(rating)?.toStringAsFixed(1) ?? rating} ($count)'),
      ]);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ]),
      );
}

void showError(BuildContext context, Object error) {
  final msg = error is ApiException ? error.displayMessage : context.t.somethingWentWrong;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// Runs an API action with a busy flag and error snackbar. Returns the result or null.
Future<T?> runAction<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  try {
    final r = await action();
    if (success != null && context.mounted) showInfo(context, success);
    return r;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String? ok}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.t.no)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok ?? c.t.yes)),
      ],
    ),
  );
  return r == true;
}

/// Asks for one line of text. Returns null if cancelled.
Future<String?> promptText(BuildContext context, String title,
    {String label = '', String? ok, bool required = false, TextInputType? keyboard, String initial = '', String? message}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setState) {
      return AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message != null) ...[Text(message, key: const Key('prompt-message')), const SizedBox(height: 8)],
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: keyboard,
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(c.t.cancel)),
          FilledButton(
            onPressed: required && ctrl.text.trim().isEmpty ? null : () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(ok ?? c.t.ok),
          ),
        ],
      );
    }),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.radius = 22});
  final String name;
  final String? url;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    return CircleAvatar(
      radius: radius,
      backgroundImage: url != null && url!.isNotEmpty ? NetworkImage(url!) : null,
      child: url != null && url!.isNotEmpty ? null : Text(initials.toUpperCase()),
    );
  }
}
