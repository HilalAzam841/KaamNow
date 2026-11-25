import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/customer/my_workers_screen.dart';
import 'package:kaamnow/ui/customer/new_request_screen.dart';
import 'package:kaamnow/ui/customer/request_detail_screen.dart';
import 'package:kaamnow/ui/customer/worker_public_screen.dart';
import 'package:kaamnow/ui/worker/job_detail_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;
import 'widget_flows_test.dart' show host;

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting());

  test('favourite and book-again fields parse', () {
    final w = PublicWorker.fromJson({...workerJson(), 'is_favourite': true, 'last_booked_at': '2026-11-20T10:00:00Z'});
    expect(w.isFavourite, isTrue);
    expect(w.lastBookedAt, isNotNull);
    expect(w.activeServices.single.category, 1);
    final r = ServiceRequest.fromJson({...requestJson(), 'invited_worker': {'id': 7, 'full_name': 'Bilal Ahmed'}});
    expect(r.invitedWorkerId, 7);
    expect(r.invitedWorkerName, 'Bilal Ahmed');
    expect(ServiceRequest.fromJson(requestJson()).invitedWorkerId, isNull);
    expect(ServiceRequest.fromJson({...requestJson(), 'is_direct': true}).isDirect, isTrue);
    expect(WorkerSlot.fromJson({'start': '2026-12-01T05:00:00Z', 'end': '2026-12-01T07:00:00Z', 'free': true}).free,
        isTrue);
  });

  testWidgets('My workers lists saved and past workers, unsaves, and books again', (tester) async {
    tall(tester);
    var saved = [{...workerJson(), 'is_favourite': true}];
    final h = await pumpScreen(tester, const MyWorkersScreen(), setup: (h) {
      h.backend.on('GET /favourites/', (_) => ok(saved));
      h.backend.on('GET /favourites/recent/', (_) => ok([
            {...workerJson(), 'is_favourite': true, 'last_booked_at': '2026-11-20T10:00:00Z'},
            {...workerJson(id: 8, name: 'Kamran Ali'), 'last_booked_at': '2026-11-10T10:00:00Z'},
          ]));
      h.backend.on('DELETE /favourites/7/', (_) {
        saved = [];
        return ok(null);
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Worked for you before'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsOneWidget, reason: 'a saved worker is not listed twice');
    expect(find.text('Kamran Ali'), findsOneWidget);
    expect(find.text('Last job for you: 10 Nov 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('favourite-7')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('DELETE /favourites/7/'), hasLength(1));
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Bilal Ahmed'), findsOneWidget, reason: 'still listed as a past worker');
  });

  testWidgets('book again opens Post a job for that worker', (tester) async {
    tall(tester);
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('GET /favourites/', (_) => ok([{...workerJson(), 'is_favourite': true}]));
    h.backend.on('GET /favourites/recent/', (_) => ok([]));
    await tester.pumpWidget(host(h.session, '/my-workers', {
      '/my-workers': (_) => const MyWorkersScreen(),
      '/requests/new': (s) => Text('new ${s.uri.query}'),
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-again-7')));
    await tester.pumpAndSettle();
    expect(find.text('new worker=7&category=1'), findsOneWidget);
  });

  testWidgets('a customer saves a worker from their profile', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const WorkerPublicScreen(id: 7), setup: (h) {
      h.backend.on('GET /workers/7/', (_) => ok({...workerJson(), 'is_favourite': false}));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([])));
      h.backend.on('POST /favourites/', (_) => ok({...workerJson(), 'is_favourite': true}, status: 201));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('worker-book')), findsOneWidget);
    await tester.tap(find.byKey(const Key('favourite-7')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /favourites/'), hasLength(1));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('Worker saved. Find them in My workers.'), findsOneWidget);
  });

  testWidgets('booking one worker shows only their free times and sends the worker', (tester) async {
    tall(tester);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    DateTime at(int hour) => DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour);
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final h = await pumpScreen(tester, const NewRequestScreen(workerId: 7, initialPin: LatLng(31.51, 74.34)),
        setup: (h) {
      h.backend.on('GET /services/categories/', (_) => ok(paged([])));
      h.backend.on('GET /workers/7/', (_) => ok(workerJson()));
      h.backend.on('GET /workers/7/slots/', (_) => ok([
            {'start': iso(at(10)), 'end': iso(at(12)), 'free': false},
            {'start': iso(at(12)), 'end': iso(at(14)), 'free': true},
          ]));
      h.backend.on('POST /requests/', (_) => ok({...requestJson(id: 30), 'matched_workers_count': 1}, status: 201));
    });
    await tester.pumpAndSettle();
    expect(find.text('Booking Bilal Ahmed'), findsOneWidget);
    expect(find.textContaining('When Bilal is free on'), findsOneWidget);
    expect(find.text('Emergency'), findsNothing);
    expect(h.backend.callsTo('GET /requests/slots/'), isEmpty);

    // A busy slot cannot be chosen; a free one can.
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('worker-slot-10'))).onSelected, isNull);
    await tester.tap(find.byKey(const Key('worker-slot-12')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12:00 PM to 2:00 PM'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('req-title')), 'Fan repair again');
    await tester.enterText(find.byKey(const Key('req-description')), 'Same fan is making noise again.');
    await tester.enterText(find.byKey(const Key('req-address')), 'House 1, Street 2, Gulberg');
    await tester.ensureVisible(find.byKey(const Key('req-submit')));
    await tester.tap(find.byKey(const Key('req-submit')));
    await tester.pumpAndSettle();
    final body = h.backend.callsTo('POST /requests/').single.body;
    expect(body, contains('name="worker"'));
    expect(RegExp(r'name="worker"\r\n\r\n7').hasMatch(body), isTrue);
    expect(RegExp(r'name="category"\r\n\r\n1').hasMatch(body), isTrue);
  });

  testWidgets('the customer sends a book-again job to everyone', (tester) async {
    final h = Harness(access: 'A', refresh: 'R');
    var invited = true;
    h.backend.on('GET /requests/11/', (_) => ok({
          ...requestJson(),
          'invited_worker': invited ? {'id': 7, 'full_name': 'Bilal Ahmed'} : null,
        }));
    h.backend.on('GET /requests/11/offers/', (_) => ok(paged([])));
    h.backend.on('POST /requests/11/open-to-all/', (_) {
      invited = false;
      return ok({...requestJson(), 'invited_worker': null, 'matched_workers_count': 4});
    });
    await tester.pumpWidget(host(h.session, '/requests/11', {
      '/requests/:id': (s) => RequestDetailScreen(id: int.parse(s.pathParameters['id']!)),
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sent only to Bilal Ahmed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-to-all')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /requests/11/open-to-all/'), hasLength(1));
    expect(find.byKey(const Key('invited-banner')), findsNothing);
  });

  testWidgets('an asked-for worker can pass on the job', (tester) async {
    tall(tester);
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('GET /requests/11/', (_) => ok({...requestJson(), 'is_direct': true}));
    h.backend.on('GET /requests/11/offers/', (_) => ok(paged([])));
    h.backend.on('POST /requests/11/decline/', (_) => ok(null));
    await tester.pumpWidget(host(h.session, '/jobs', {
      '/jobs': (_) => Builder(builder: (c) => TextButton(onPressed: () => c.push('/jobs/11'), child: const Text('feed'))),
      '/jobs/:id': (s) => JobDetailScreen(id: int.parse(s.pathParameters['id']!)),
    }));
    await tester.tap(find.text('feed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asked-for-you')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('decline-direct')));
    await tester.tap(find.byKey(const Key('decline-direct')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pass on it'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /requests/11/decline/'), hasLength(1));
    expect(find.text('feed'), findsOneWidget);
  });
}
