import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/core/api_client.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/customer/worker_public_screen.dart';
import 'package:kaamnow/ui/worker/portfolio_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> photoJson(int id, {String caption = '', bool hidden = false, String reason = ''}) => {
      'id': id,
      'image': 'https://media.kaamnow.pk/workers/portfolio/$id.jpg',
      'caption': caption,
      'category': 1,
      'category_name': 'Electrician',
      'from_job': id == 1,
      'created_at': '2026-11-20T10:00:00Z',
      'booking': id == 1 ? 21 : null,
      'position': id,
      'is_hidden': hidden,
      'hidden_reason': reason,
      'worker': 7,
      'worker_name': 'Bilal Ahmed',
    };

Map<String, dynamic> workerProfileJson() => {
      'id': 7,
      'full_name': 'Bilal Ahmed',
      'phone': '+923007654321',
      'services': workerJson()['services'],
    };

void big(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('portfolio photos parse, on their own and on a profile', () {
    final p = PortfolioPhoto.fromJson(photoJson(1, caption: 'Kitchen wiring'));
    expect(p.fromJob, isTrue);
    expect(p.categoryName, 'Electrician');
    final w = PublicWorker.fromJson({...workerJson(), 'portfolio': [photoJson(1), photoJson(2)]});
    expect(w.portfolio.map((p) => p.id), [1, 2]);
    expect(PublicWorker.fromJson(workerJson()).portfolio, isEmpty);
    expect(PortfolioPhoto.fromJson(photoJson(3, hidden: true, reason: 'Blurry')).hiddenReason, 'Blurry');
  });

  testWidgets('a worker adds a photo with a caption and service', (tester) async {
    big(tester);
    final photos = <Map<String, dynamic>>[];
    final h = await pumpScreen(
      tester,
      PortfolioScreen(picker: () async => UploadFile(field: 'image', filename: 'job.jpg', bytes: Uint8List(8))),
      role: 'worker',
      setup: (h) {
        h.backend.on('GET /workers/me/portfolio/', (_) => ok(photos));
        h.backend.on('GET /workers/me/', (_) => ok(workerProfileJson()));
        h.backend.on('POST /workers/me/portfolio/', (_) {
          photos.add(photoJson(5, caption: 'New fan'));
          return ok(photos.last, status: 201);
        });
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No work photos yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-photo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('photo-caption')), 'New fan');
    await tester.tap(find.byKey(const Key('photo-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electrician').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-photo')));
    await tester.pumpAndSettle();
    final body = h.backend.callsTo('POST /workers/me/portfolio/').single.body;
    expect(RegExp(r'name="caption"\r\n\r\nNew fan').hasMatch(body), isTrue);
    expect(RegExp(r'name="category"\r\n\r\n1').hasMatch(body), isTrue);
    expect(body, contains('name="image"; filename="job.jpg"'));
    expect(find.byKey(const Key('my-photo-5')), findsOneWidget);
    expect(find.text('1 of 12 photos'), findsOneWidget);
  });

  testWidgets('a worker reorders, sees a hidden photo and deletes one', (tester) async {
    big(tester);
    var photos = [photoJson(1, caption: 'First'), photoJson(2, caption: 'Second', hidden: true, reason: 'Blurry')];
    final h = await pumpScreen(tester, const PortfolioScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /workers/me/portfolio/', (_) => ok(photos));
      h.backend.on('GET /workers/me/', (_) => ok(workerProfileJson()));
      h.backend.on('POST /workers/me/portfolio/reorder/', (r) {
        final ids = ((jsonDecode(r.body) as Map)['ids'] as List).cast<int>();
        photos = [for (final id in ids) photos.firstWhere((p) => p['id'] == id)];
        return ok(photos);
      });
      h.backend.on('DELETE /workers/me/portfolio/1/', (_) {
        photos = photos.where((p) => p['id'] != 1).toList();
        return ok(null);
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('Hidden by KaamNow: Blurry'), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-menu-2')));
    await tester.pumpAndSettle();
    expect(find.text('Move later'), findsNothing);
    await tester.tap(find.text('Move earlier'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /workers/me/portfolio/reorder/').single.body), {'ids': [2, 1]});
    await tester.tap(find.byKey(const Key('photo-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('DELETE /workers/me/portfolio/1/'), hasLength(1));
    expect(find.byKey(const Key('my-photo-1')), findsNothing);
  });

  testWidgets('customers see past work on a profile and can open a photo', (tester) async {
    big(tester);
    await pumpScreen(tester, const WorkerPublicScreen(id: 7), setup: (h) {
      h.backend.on('GET /workers/7/', (_) => ok({...workerJson(), 'portfolio': [photoJson(1, caption: 'Kitchen wiring')]}));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([])));
    });
    await tester.pumpAndSettle();
    expect(find.text('Past work'), findsOneWidget);
    await tester.tap(find.byKey(const Key('portfolio-1')));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen wiring\nFrom a KaamNow job'), findsOneWidget);
  });

  testWidgets('admin hides a photo with a reason', (tester) async {
    final h = await adminHarness();
    h.backend.on('GET /admin/portfolio-photos/', (_) => ok(paged([photoJson(2, caption: 'Odd photo')])));
    h.backend.on('POST /admin/portfolio-photos/2/hide/', (_) => ok(photoJson(2, hidden: true, reason: 'Not work')));
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2000);
    await tester.tap(find.text('Portfolio photos').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bilal Ahmed · Odd photo'), findsOneWidget);
    expect(h.backend.callsTo('GET /admin/portfolio-photos/').first.url.queryParameters['is_hidden'], 'false');
    await tester.tap(find.byKey(const Key('admin-photo-toggle-2')));
    await tester.pumpAndSettle();
    expect(find.text('Hide this photo?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Not work');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /admin/portfolio-photos/2/hide/').single.body), {'reason': 'Not work'});
  });
}
