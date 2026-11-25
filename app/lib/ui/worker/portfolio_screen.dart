import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

const maxPortfolioPhotos = 12;

/// Picks one picture from the gallery. Replaced in tests.
typedef PhotoPicker = Future<UploadFile?> Function();

Future<UploadFile?> pickPortfolioPhoto() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
  if (f == null) return null;
  return UploadFile(field: 'image', filename: f.name, bytes: await f.readAsBytes());
}

/// Full-screen view of one photo with its caption.
void openPhoto(BuildContext context, PortfolioPhoto p) {
  showDialog<void>(
    context: context,
    builder: (d) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(children: [
        Center(
          child: InteractiveViewer(
            child: Image.network(p.image, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white, size: 48)),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
              color: Colors.white, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(d)),
        ),
        if (p.caption.isNotEmpty || p.fromJob)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Text(
              [if (p.caption.isNotEmpty) p.caption, if (p.fromJob) context.t.fromKaamNowJob].join('\n'),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
      ]),
    ),
  );
}

/// Square tile of a portfolio photo.
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.photo, this.size = 120, this.onTap, this.badge});
  final PortfolioPhoto photo;
  final double size;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Image.network(photo.image, width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => SizedBox(width: size, height: size, child: const Icon(Icons.broken_image))),
            if (photo.fromJob)
              const Positioned(left: 4, top: 4, child: Icon(Icons.verified, color: Colors.white, size: 18)),
            ?badge,
          ]),
        ),
      );
}

/// Horizontal "Past work" strip on a worker's public profile.
class PortfolioStrip extends StatelessWidget {
  const PortfolioStrip({super.key, required this.photos});
  final List<PortfolioPhoto> photos;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: ListView.separated(
          key: const Key('portfolio-strip'),
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => PhotoTile(
            key: Key('portfolio-${photos[i].id}'),
            photo: photos[i],
            onTap: () => openPhoto(context, photos[i]),
          ),
        ),
      );
}

/// The worker's own work photos: add, caption, reorder and delete.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, this.picker = pickPortfolioPhoto});
  final PhotoPicker picker;
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _loader = GlobalKey<LoaderState<(List<PortfolioPhoto>, List<WorkerServiceInline>)>>();

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _add(List<WorkerServiceInline> services) async {
    final t = context.t;
    final file = await widget.picker();
    if (file == null || !mounted) return;
    final caption = TextEditingController();
    int? category;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(t.addPhoto),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(file.bytes, height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image, size: 64)),
            ),
            TextField(
              key: const Key('photo-caption'),
              controller: caption,
              maxLength: 150,
              decoration: InputDecoration(labelText: t.photoCaptionLabel),
            ),
            if (services.isNotEmpty)
              DropdownButtonFormField<int?>(
                key: const Key('photo-service'),
                initialValue: category,
                decoration: InputDecoration(labelText: t.photoServiceLabel),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(t.noService)),
                  for (final s in services) DropdownMenuItem<int?>(value: s.category, child: Text(s.categoryName)),
                ],
                onChanged: (v) => set(() => category = v),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t.cancel)),
            FilledButton(key: const Key('upload-photo'), onPressed: () => Navigator.pop(d, true), child: Text(t.save)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runAction(context,
        () => context.read<Session>().api.addPortfolioPhoto(file, caption: caption.text.trim(), category: category),
        success: t.photoAdded);
    if (r != null) await _reload();
  }

  Future<void> _act(String action, PortfolioPhoto p, List<PortfolioPhoto> all) async {
    final t = context.t;
    final api = context.read<Session>().api;
    switch (action) {
      case 'caption':
        final text = await promptText(context, t.editCaption, label: t.photoCaptionLabel, initial: p.caption);
        if (text == null || !mounted) return;
        final r = await runAction(context, () => api.updatePortfolioPhoto(p.id, {'caption': text.trim()}));
        if (r != null) await _reload();
      case 'earlier' || 'later':
        final ids = [for (final x in all) x.id];
        final i = ids.indexOf(p.id);
        final j = action == 'earlier' ? i - 1 : i + 1;
        if (j < 0 || j >= ids.length) return;
        ids[i] = ids[j];
        ids[j] = p.id;
        final r = await runAction(context, () => api.reorderPortfolio(ids));
        if (r != null) await _reload();
      case 'delete':
        if (!await confirm(context, t.deletePhotoQ, t.deletePhotoBody, ok: t.remove) || !mounted) return;
        final r = await runAction(context, () async {
          await api.deletePortfolioPhoto(p.id);
          return true;
        }, success: t.photoDeleted);
        if (r == true) await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(t.myPortfolio)),
      body: PageBody(
        child: Loader<(List<PortfolioPhoto>, List<WorkerServiceInline>)>(
          key: _loader,
          load: () async => (await api.myPortfolio(), (await api.myWorkerProfile()).services),
          builder: (context, data, reload) {
            final (photos, services) = data;
            final full = photos.length >= maxPortfolioPhotos;
            return ListView(padding: const EdgeInsets.all(16), children: [
              if (photos.isEmpty)
                EmptyView(icon: Icons.photo_library, title: t.noPortfolioYet, subtitle: t.noPortfolioHint)
              else ...[
                Text(t.photosCount(photos.length, maxPortfolioPhotos), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                for (var i = 0; i < photos.length; i++)
                  Card(
                    key: Key('my-photo-${photos[i].id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        PhotoTile(photo: photos[i], size: 96, onTap: () => openPhoto(context, photos[i])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (photos[i].caption.isNotEmpty) Text(photos[i].caption),
                            if (photos[i].categoryName != null)
                              Text(photos[i].categoryName!, style: Theme.of(context).textTheme.bodySmall),
                            if (photos[i].fromJob)
                              Text(t.fromKaamNowJob, style: Theme.of(context).textTheme.bodySmall),
                            if (photos[i].isHidden)
                              Text(t.photoHiddenBy(photos[i].hiddenReason),
                                  key: Key('photo-hidden-${photos[i].id}'), style: const TextStyle(color: Colors.red)),
                          ]),
                        ),
                        PopupMenuButton<String>(
                          key: Key('photo-menu-${photos[i].id}'),
                          onSelected: (v) => _act(v, photos[i], photos),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'caption', child: Text(t.editCaption)),
                            if (i > 0) PopupMenuItem(value: 'earlier', child: Text(t.moveEarlier)),
                            if (i < photos.length - 1) PopupMenuItem(value: 'later', child: Text(t.moveLater)),
                            PopupMenuItem(value: 'delete', child: Text(t.remove)),
                          ],
                        ),
                      ]),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              if (full)
                Text(t.maxPhotosReached, textAlign: TextAlign.center)
              else
                FilledButton.icon(
                  key: const Key('add-photo'),
                  onPressed: () => _add(services.where((s) => s.isActive).toList()),
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(t.addPhoto),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
