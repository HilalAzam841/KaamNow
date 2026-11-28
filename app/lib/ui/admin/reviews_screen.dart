import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import '../widgets/review_card.dart' show openReviewPhoto;
import 'admin_common.dart';
import 'admin_shell.dart';

/// Reviews, their photos and the workers' replies. Hide what breaks the rules; every action is audited.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});
  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  String? _filter = 'photos';
  final _list = GlobalKey<PagedListState<AdminReview>>();

  Future<void> _run(Future<AdminReview> Function() action, String done, VoidCallback reload) async {
    final r = await runAction(context, action, success: done);
    if (r != null) reload();
  }

  Future<String?> _reason(String title) =>
      promptText(context, title, label: 'Reason (recorded in the audit log)', ok: 'Hide', required: true);

  Future<void> _hideReview(AdminReview r, VoidCallback reload) async {
    final reason = await _reason('Hide this review?');
    if (reason == null || !mounted) return;
    await _run(() => adminApi(context).hideReview(r.id, reason.trim()),
        "Review hidden. It no longer counts toward the worker's rating.", reload);
  }

  Future<void> _removeReply(AdminReview r, VoidCallback reload) async {
    final reason = await _reason("Remove the worker's reply?");
    if (reason == null || !mounted) return;
    await _run(() => adminApi(context).removeReviewReply(r.id, reason.trim()), 'Reply removed.', reload);
  }

  Future<void> _togglePhoto(AdminReview r, AdminReviewPhoto p, VoidCallback reload) async {
    if (p.isHidden) {
      await _run(() => adminApi(context).setReviewPhotoHidden(r.id, p.id, false), 'Photo shown again.', reload);
      return;
    }
    final reason = await _reason('Hide this photo?');
    if (reason == null || !mounted) return;
    await _run(() => adminApi(context).setReviewPhotoHidden(r.id, p.id, true, reason: reason.trim()), 'Photo hidden.',
        reload);
  }

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Reviews',
        body: Column(children: [
          FilterChips(
            options: const [('photos', 'With photos'), ('visible', 'Shown'), ('hidden', 'Hidden'), (null, 'All')],
            selected: _filter,
            onSelected: (v) {
              setState(() => _filter = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<AdminReview>(
              key: _list,
              empty: 'No reviews',
              load: (page) => adminApi(context).reviews(
                visible: switch (_filter) { 'visible' => true, 'hidden' => false, _ => null },
                withPhotos: _filter == 'photos',
                page: page,
              ),
              itemBuilder: (context, r, reload) => Card(
                key: Key('admin-review-${r.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${'★' * r.rating}${'☆' * (5 - r.rating)} · ${r.customerName} → ${r.workerName}'
                        ' · booking #${r.bookingId}${r.isVisible ? '' : ' · HIDDEN'}'),
                    if (r.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment)),
                    if (r.photos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final p in r.photos)
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              InkWell(
                                onTap: () => openReviewPhoto(context, p.image),
                                child: Opacity(
                                  opacity: p.isHidden ? 0.35 : 1,
                                  child: Image.network(p.image, width: 72, height: 72, fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(width: 72, height: 72, child: Icon(Icons.broken_image))),
                                ),
                              ),
                              TextButton(
                                key: Key('admin-review-photo-${p.id}'),
                                onPressed: () => _togglePhoto(r, p, reload),
                                child: Text(p.isHidden ? 'Show' : 'Hide'),
                              ),
                            ]),
                        ]),
                      ),
                    if (r.reply.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Worker reply: ${r.reply}', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    if (r.createdAt != null) Text(when(r.createdAt), style: Theme.of(context).textTheme.bodySmall),
                    Wrap(spacing: 4, children: [
                      if (r.isVisible)
                        TextButton(
                            key: Key('admin-review-hide-${r.id}'),
                            onPressed: () => _hideReview(r, reload),
                            child: const Text('Hide review'))
                      else
                        TextButton(
                            key: Key('admin-review-unhide-${r.id}'),
                            onPressed: () => _run(() => adminApi(context).unhideReview(r.id), 'Review shown again.', reload),
                            child: const Text('Show review')),
                      if (r.reply.isNotEmpty)
                        TextButton(
                            key: Key('admin-review-remove-reply-${r.id}'),
                            onPressed: () => _removeReply(r, reload),
                            child: const Text('Remove reply')),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );
}
