import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../widgets/review_card.dart';

/// The worker's reviews, with a Reply button on each one they have not answered yet.
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});
  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _loader = GlobalKey<LoaderState<(WorkerProfile, Paged<Review>)>>();

  Future<void> _reply(Review r) async {
    final t = context.t;
    final text = await promptText(context, t.reviewReplyTitle,
        label: t.reviewReplyLabel, message: t.reviewReplyHint, ok: t.reviewReply, required: true);
    if (text == null || text.trim().isEmpty || !mounted) return;
    final ok = await runAction(context, () => context.read<Session>().api.replyToReview(r.id, text.trim()),
        success: t.reviewReplySent);
    if (ok != null) await _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(t.myReviews), actions: const [LanguageButton()]),
      body: PageBody(
        child: Loader<(WorkerProfile, Paged<Review>)>(
          key: _loader,
          load: () async {
            final me = await api.myWorkerProfile();
            return (me, await api.workerReviews(me.id));
          },
          builder: (context, data, reload) {
            final (me, reviews) = data;
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text(t.reviewsHeading(reviews.count), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (reviews.results.isEmpty) Text(t.noReviewsYet),
                for (final r in reviews.results)
                  ReviewCard(review: r, workerName: me.fullName.split(' ').first, onReply: () => _reply(r)),
              ]),
            );
          },
        ),
      ),
    );
  }
}
