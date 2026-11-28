import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/core/api_client.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

// A 1x1 transparent PNG.
final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

Map<String, dynamic> photoJson(int id, String kind) => {
      'id': id, 'booking': 21, 'kind': kind, 'caption': '',
      'file_url': '/api/v1/bookings/21/photos/$id/file/', 'created_at': '2026-11-28T10:00:00Z',
    };

Map<String, dynamic> summaryJson({int before = 0, int after = 0, bool canBefore = false, bool canAfter = false}) =>
    {'before': before, 'after': after, 'max_per_kind': 5, 'can_add_before': canBefore, 'can_add_after': canAfter};

Map<String, dynamic> withPhotos(Map<String, dynamic> booking, Map<String, dynamic> summary) =>
    {...booking, 'job_photos': summary};

void main() {
  setUpAll(() => initializeDateFormatting());

  test('booking photo summary and photos parse', () {
    final b = Booking.fromJson(withPhotos(bookingJson(), summaryJson(before: 2, canAfter: true)));
    expect(b.jobPhotos.before, 2);
    expect(b.jobPhotos.total, 2);
    expect(b.jobPhotos.canAdd('after'), isTrue);
    expect(b.jobPhotos.canAdd('before'), isFalse);
    expect(Booking.fromJson(bookingJson()).jobPhotos.total, 0, reason: 'older servers send no summary');
    final p = JobPhoto.fromJson(photoJson(5, 'after'));
    expect(p.kind, 'after');
    expect(p.fileUrl, '/api/v1/bookings/21/photos/5/file/');
  });

  void common(Harness h, Map<String, dynamic> booking) {
    h.backend.on('GET /bookings/21/', (_) => ok(booking));
    h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
    h.backend.on('GET /payments/', (_) => ok(paged([])));
    h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
    for (final id in [5, 6, 7]) {
      h.backend.on('GET /bookings/21/photos/$id/file/',
          (_) => http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}));
    }
  }

  testWidgets('the worker adds a before photo once arrived', (tester) async {
    tall(tester);
    final photos = <Map<String, dynamic>>[];
    final h = await pumpScreen(
      tester,
      BookingDetailScreen(
          id: 21, photoPicker: () async => UploadFile(field: 'image', filename: 'board.jpg', bytes: Uint8List(8))),
      role: 'worker',
      setup: (h) {
        common(h, withPhotos(bookingJson(status: 'arrived'), summaryJson(canBefore: true)));
        h.backend.on('GET /bookings/21/photos/', (_) =>
            ok({'summary': summaryJson(before: photos.length, canBefore: true), 'results': photos}));
        h.backend.on('POST /bookings/21/photos/', (req) {
          photos.add(photoJson(5, 'before'));
          return ok(photos.last, status: 201);
        });
      },
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-photos')), findsOneWidget);
    expect(find.byKey(const Key('add-after-photo')), findsNothing, reason: 'work has not started');

    await tester.ensureVisible(find.byKey(const Key('add-before-photo')));
    await tester.tap(find.byKey(const Key('add-before-photo')));
    await tester.pumpAndSettle();
    final post = h.backend.callsTo('POST /bookings/21/photos/').single;
    expect(post.headers['content-type'], startsWith('multipart/form-data'));
    expect(utf8.decode(post.bodyBytes, allowMalformed: true), contains('name="kind"\r\n\r\nbefore'));
    expect(find.text('Photo added.'), findsOneWidget);
    expect(find.byKey(const Key('job-photo-5')), findsOneWidget);
    expect(h.backend.callsTo('GET /bookings/21/photos/5/file/'), hasLength(1),
        reason: 'private photo is downloaded with the login');
  });

  testWidgets('the customer sees before and after photos but cannot add or remove', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      common(h, withPhotos(bookingJson(status: 'completed'), summaryJson(before: 1, after: 2)));
      h.backend.on('GET /bookings/21/photos/', (_) => ok({
            'summary': summaryJson(before: 1, after: 2),
            'results': [photoJson(5, 'before'), photoJson(6, 'after'), photoJson(7, 'after')],
          }));
    });
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    for (final id in [5, 6, 7]) {
      expect(find.byKey(Key('job-photo-$id')), findsOneWidget);
      expect(find.byKey(Key('remove-job-photo-$id')), findsNothing);
    }
    expect(find.byKey(const Key('add-before-photo')), findsNothing);
    expect(find.byKey(const Key('add-after-photo')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('job-photo-6')));
    await tester.tap(find.byKey(const Key('job-photo-6')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(h.backend.callsTo('GET /bookings/21/photos/6/file/'), hasLength(1), reason: 'the download is reused');
  });

  testWidgets('no photos section when there are none and nothing to add', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      common(h, withPhotos(bookingJson(status: 'confirmed'), summaryJson()));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-photos')), findsNothing);
    expect(h.backend.callsTo('GET /bookings/21/photos/'), isEmpty);
  });
}
