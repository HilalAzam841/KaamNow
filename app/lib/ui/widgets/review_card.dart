import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';

/// Full-screen view of a review photo.
void openReviewPhoto(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (d) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(children: [
        Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white, size: 48)),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(color: Colors.white, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(d)),
        ),
      ]),
    ),
  );
}

/// A review: stars, the customer's first name, comment, photos and the worker's reply.
/// [onReply] shows a Reply button when the viewer is the reviewed worker and has not replied.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, required this.workerName, this.onReply});
  final Review review;
  final String workerName;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final theme = Theme.of(context);
    return Card(
      key: Key('review-${r.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var i = 0; i < 5; i++)
              Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(r.customerName, style: theme.textTheme.bodySmall)),
          ]),
          if (r.comment.isNotEmpty) ...[const SizedBox(height: 6), Text(r.comment)],
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in r.photos)
                InkWell(
                  key: Key('review-photo-${p.id}'),
                  onTap: () => openReviewPhoto(context, p.image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(p.image, width: 72, height: 72, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(width: 72, height: 72, child: Icon(Icons.broken_image))),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 6),
          Text('${r.categoryName} · ${day(r.createdAt)}', style: theme.textTheme.bodySmall),
          if (r.reply.isNotEmpty)
            Container(
              key: Key('review-reply-${r.id}'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t.reviewWorkerReply(workerName), style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(r.reply),
              ]),
            ),
          if (r.canReply && onReply != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: Key('review-reply-button-${r.id}'),
                onPressed: onReply,
                icon: const Icon(Icons.reply),
                label: Text(context.t.reviewReply),
              ),
            ),
        ]),
      ),
    );
  }
}
