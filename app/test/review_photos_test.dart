import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/core/api_client.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:kaamnow/ui/customer/worker_public_screen.dart';
import 'package:kaamnow/ui/worker/my_reviews_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'portfolio_test.dart' show workerProfileJson;
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> reviewJson({int id = 9, List<int> photos = const [], String reply = '', bool canReply = false,
        String comment = 'Fixed it fast'}) =>
    {
      'id': id, 'booking': 21, 'worker': 7, 'rating': 4, 'comment': comment, 'customer_name': 'Ayesha',
      'category_name': 'Electrician',
      'photos': [for (final p in photos) {'id': p, 'image': 'https://media.kaamnow.pk/reviews/photos/$p.jpg'}],
      'reply': reply, 'replied_at': reply.isEmpty ? null : '2026-11-27T10:00:00Z', 'can_reply': canReply,
      'created_at': '2026-11-27T09:00:00Z',
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('review with photos and reply parses', () {
    final r = Review.fromJson(reviewJson(photos: [1, 2], reply: 'Thanks!', canReply: false));
    expect(r.photos.map((p) => p.id), [1, 2]);
    expect(r.reply, 'Thanks!');
    expect(r.repliedAt, isNotNull);
    expect(Review.fromJson({'id': 1, 'rating': 5}).photos, isEmpty);
  });

  testWidgets('after the customer confirms the job is done, the rating opens straight away', (tester) async {
    tall(tester);
    var status = 'in_progress';
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      h.backend.on('GET /bookings/21/', (_) => ok(bookingJson(status: status)));
      h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
      h.backend.on('GET /payments/', (_) => ok(paged([])));
      h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
      h.backend.on('POST /bookings/21/complete/', (_) {
        status = 'completed';
        return ok(bookingJson(status: 'completed'));
      });
      h.backend.on('POST /reviews/', (req) {
        expect((jsonDecode(req.body) as Map)['rating'], 5);
        return ok(reviewJson(), status: 201);
      });
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('confirm-complete')));
    await tester.tap(find.byKey(const Key('confirm-complete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete').last);
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /bookings/21/complete/'), hasLength(1));
    expect(find.byKey(const Key('submit-review')), findsOneWidget, reason: 'rating dialog opened by itself');

    await tester.tap(find.byKey(const Key('star-5')));
    await tester.tap(find.byKey(const Key('submit-review')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /reviews/'), hasLength(1));
  });

  testWidgets('a customer reviews with photos and both are uploaded', (tester) async {
    tall(tester);
    var picks = 0;
    final h = await pumpScreen(
      tester,
      BookingDetailScreen(
          id: 21,
          photoPicker: () async => UploadFile(field: 'image', filename: 'job${++picks}.jpg', bytes: Uint8List(8))),
      setup: (h) {
        h.backend.on('GET /bookings/21/', (_) => ok(bookingJson(status: 'completed')));
        h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
        h.backend.on('GET /payments/', (_) => ok(paged([])));
        h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
        h.backend.on('POST /reviews/', (_) => ok(reviewJson(), status: 201));
        h.backend.on('POST /reviews/9/photos/', (_) => ok({'id': 1, 'image': 'https://x/1.jpg'}, status: 201));
      },
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('leave-review')));
    await tester.tap(find.byKey(const Key('leave-review')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('review-add-photo')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('review-add-photo')), findsNothing, reason: 'three photos at most');
    await tester.tap(find.byKey(const Key('review-photo-remove-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.tap(find.byKey(const Key('submit-review')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /reviews/').single.body)['rating'], 4);
    final uploads = h.backend.callsTo('POST /reviews/9/photos/');
    expect(uploads, hasLength(2));
    expect(uploads.first.body, contains('filename="job1.jpg"'));
    expect(find.text('Thanks for your review!'), findsOneWidget);
  });

  testWidgets('the profile shows photos, the reply and a with-photos filter', (tester) async {
    tall(tester);
    await pumpScreen(tester, const WorkerPublicScreen(id: 7), setup: (h) {
      h.backend.on('GET /workers/7/', (_) => ok(workerJson()));
      h.backend.on('GET /workers/7/packages/', (_) => ok([]));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([
            reviewJson(id: 9, photos: [1], reply: 'Thank you, Ayesha!'),
            reviewJson(id: 10, comment: 'OK job'),
          ])));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-photo-1')), findsOneWidget);
    expect(find.text('Reply from Bilal'), findsOneWidget);
    expect(find.text('Thank you, Ayesha!'), findsOneWidget);
    expect(find.text('OK job'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reviews-with-photos')));
    await tester.tap(find.byKey(const Key('reviews-with-photos')));
    await tester.pumpAndSettle();
    expect(find.text('OK job'), findsNothing);
    expect(find.byKey(const Key('review-reply-button-9')), findsNothing);
  });

  testWidgets('a worker replies to a review once', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const MyReviewsScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /workers/me/', (_) => ok(workerProfileJson()));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([reviewJson(canReply: true)])));
      h.backend.on('POST /reviews/9/reply/', (_) => ok(reviewJson(reply: 'Shukriya!')));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-reply-button-9')));
    await tester.pumpAndSettle();
    expect(find.text('Everyone can see your reply. You can reply once.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Shukriya!');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /reviews/9/reply/').single.body), {'reply': 'Shukriya!'});
    expect(find.text('Reply posted.'), findsOneWidget);
  });

  test('photo upload and delete call the server', () async {
    final h = Harness(access: 'A');
    h.backend.on('POST /reviews/9/photos/', (_) => ok({'id': 3, 'image': 'https://x/3.jpg'}, status: 201));
    h.backend.on('DELETE /reviews/9/photos/3/', (_) => ok(null, status: 204));
    final p = await h.api.addReviewPhoto(9, UploadFile(field: 'image', filename: 'a.jpg', bytes: Uint8List(4)));
    expect(p.id, 3);
    await h.api.deleteReviewPhoto(9, 3);
    expect(h.backend.callsTo('DELETE /reviews/9/photos/3/'), hasLength(1));
  });

  testWidgets('admin hides a review photo with a reason', (tester) async {
    final h = await adminHarness();
    Map<String, dynamic> adminReview({bool photoHidden = false}) => {
          ...reviewJson(photos: [1], reply: 'Rude'), 'worker_name': 'Bilal Ahmed', 'customer': 3,
          'customer_name': 'Ayesha Khan', 'is_visible': true,
          'photos': [{'id': 1, 'image': 'https://x/1.jpg', 'is_hidden': photoHidden, 'hidden_reason': ''}],
        };
    h.backend.on('GET /admin/reviews/', (_) => ok(paged([adminReview()])));
    h.backend.on('POST /admin/reviews/9/photos/1/hide/', (_) => ok(adminReview(photoHidden: true)));
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2400);
    await tester.tap(find.text('Reviews').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayesha Khan → Bilal Ahmed'), findsOneWidget);
    expect(h.backend.callsTo('GET /admin/reviews/').first.url.queryParameters['with_photos'], 'true');
    expect(find.byKey(const Key('admin-review-remove-reply-9')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-review-photo-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Shows a face');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /admin/reviews/9/photos/1/hide/').single.body), {'reason': 'Shows a face'});
  });
}
