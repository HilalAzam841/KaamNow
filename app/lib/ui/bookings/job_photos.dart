import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../worker/portfolio_screen.dart' show PhotoPicker;

typedef PhotoLoader = Future<Uint8List> Function(JobPhoto photo);

/// Before and after photos on a booking.
///
/// The worker adds them (before: once arrived; after: once work started, up to a day after
/// completion). The customer and admins see them. The pictures are private, so each one is
/// downloaded with the viewer's login rather than shown from a public URL.
class JobPhotosSection extends StatefulWidget {
  const JobPhotosSection({
    super.key,
    required this.load,
    required this.loadBytes,
    this.add,
    this.delete,
    this.picker,
    this.onChanged,
  });

  final Future<(JobPhotoSummary, List<JobPhoto>)> Function() load;
  final PhotoLoader loadBytes;

  /// Set for the worker: adds a photo of a kind.
  final Future<JobPhoto> Function(String kind, UploadFile image)? add;
  final Future<void> Function(JobPhoto photo)? delete;
  final PhotoPicker? picker;
  final VoidCallback? onChanged;

  @override
  State<JobPhotosSection> createState() => _JobPhotosSectionState();
}

class _JobPhotosSectionState extends State<JobPhotosSection> {
  final _bytes = <int, Future<Uint8List>>{};
  JobPhotoSummary _summary = const JobPhotoSummary();
  List<JobPhoto> _photos = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final (summary, photos) = await widget.load();
      if (mounted) {
        setState(() {
          _summary = summary;
          _photos = photos;
        });
      }
    } catch (_) {
      // The rest of the booking still works; the section just stays empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _image(JobPhoto p) => _bytes.putIfAbsent(p.id, () => widget.loadBytes(p));

  Future<void> _add(String kind) async {
    final file = await widget.picker?.call();
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    final added = await runAction(context, () => widget.add!(kind, file), success: context.t.jobPhotoAdded);
    if (mounted) setState(() => _busy = false);
    if (added != null) {
      await _reload();
      widget.onChanged?.call();
    }
  }

  Future<void> _delete(JobPhoto p) async {
    if (!await confirm(context, context.t.removePhotoQ, context.t.removePhotoBody, ok: context.t.remove)) return;
    if (!mounted) return;
    final ok = await runAction(context, () async {
      await widget.delete!(p);
      return true;
    });
    if (ok == true) {
      _bytes.remove(p.id);
      await _reload();
      widget.onChanged?.call();
    }
  }

  void _open(JobPhoto p) {
    showDialog<void>(
      context: context,
      builder: (d) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: FutureBuilder<Uint8List>(
                  future: _image(p),
                  builder: (_, snap) => snap.hasData
                      ? Image.memory(snap.data!, fit: BoxFit.contain)
                      : snap.hasError
                      ? const Icon(Icons.broken_image, color: Colors.white, size: 48)
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
            if (p.caption.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Text(
                  p.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: d.t.close,
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAddAny = widget.add != null && (_summary.canAddBefore || _summary.canAddAfter);
    if (_loading || (_photos.isEmpty && !canAddAny)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const Key('job-photos'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.jobPhotos, style: theme.textTheme.titleMedium),
            if (widget.add != null) ...[
              const SizedBox(height: 4),
              Text(context.t.jobPhotosWorkerHint, style: theme.textTheme.bodySmall),
            ],
            for (final kind in const ['before', 'after']) _row(context, kind),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String kind) {
    final photos = _photos.where((p) => p.kind == kind).toList();
    final canAdd = widget.add != null && _summary.canAdd(kind);
    if (photos.isEmpty && !canAdd) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == 'before' ? context.t.beforeWork : context.t.afterWork,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in photos) _thumb(p, removable: canAdd && widget.delete != null),
              if (canAdd)
                SizedBox(
                  width: 72,
                  height: 72,
                  child: OutlinedButton(
                    key: Key('add-$kind-photo'),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _busy ? null : () => _add(kind),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Tooltip(
                            message: kind == 'before' ? context.t.addBeforePhoto : context.t.addAfterPhoto,
                            child: const Icon(Icons.add_a_photo),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumb(JobPhoto p, {required bool removable}) => Stack(
    children: [
      InkWell(
        key: Key('job-photo-${p.id}'),
        onTap: () => _open(p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 72,
            height: 72,
            child: FutureBuilder<Uint8List>(
              future: _image(p),
              builder: (_, snap) => snap.hasData
                  ? Image.memory(
                      snap.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                    )
                  : ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(snap.hasError ? Icons.broken_image : Icons.image_outlined),
                    ),
            ),
          ),
        ),
      ),
      if (removable)
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            key: Key('remove-job-photo-${p.id}'),
            onTap: () => _delete(p),
            child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)),
          ),
        ),
    ],
  );
}
