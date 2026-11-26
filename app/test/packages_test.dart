import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:kaamnow/ui/customer/book_package_screen.dart';
import 'package:kaamnow/ui/customer/packages_screen.dart';
import 'package:kaamnow/ui/customer/worker_public_screen.dart';
import 'package:kaamnow/ui/worker/packages_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'addresses_test.dart' show addressJson;
import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'portfolio_test.dart' show workerProfileJson;
import 'promos_test.dart' show pumpScreen;
import 'widget_flows_test.dart' show host;

Map<String, dynamic> packageJson(int id,
        {String title = 'AC service', String price = '2500.00', bool active = true, bool hidden = false,
        String reason = '', bool withWorker = true, int booked = 0}) =>
    {
      'id': id,
      'title': title,
      'description': 'Indoor and outdoor unit clean.',
      'includes': ['Filter wash', 'Gas pressure check'],
      'price': price,
      'duration_minutes': 90,
      'category': 1,
      'category_name': 'Electrician',
      'times_booked': booked,
      'is_active': active,
      'is_hidden': hidden,
      'hidden_reason': reason,
      if (withWorker)
        'worker': {
          'id': 7,
          'full_name': 'Bilal Ahmed',
          'profile_picture': null,
          'average_rating': '4.60',
          'rating_count': 12,
          'completed_jobs_count': 40,
          'level': 'trusted',
        },
      'worker_name': 'Bilal Ahmed',
    };

/// Tomorrow's slots: 9 is taken, 11 and 13 are free.
List<Map<String, dynamic>> slotsJson() {
  final d = DateTime.now().add(const Duration(days: 1));
  String at(int h) => DateTime(d.year, d.month, d.day, h).toUtc().toIso8601String();
  return [
    {'start': at(9), 'end': at(11), 'free': false},
    {'start': at(11), 'end': at(13), 'free': true},
    {'start': at(13), 'end': at(15), 'free': true},
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting());

  test('packages parse, with and without the worker', () {
    final p = ServicePackage.fromJson(packageJson(3, booked: 4));
    expect(p.includes, ['Filter wash', 'Gas pressure check']);
    expect(p.durationMinutes, 90);
    expect(p.worker!.level, 'trusted');
    expect(p.timesBooked, 4);
    expect(ServicePackage.fromJson(packageJson(4, withWorker: false)).worker, isNull);
    expect(Booking.fromJson({...bookingJson(), 'package_id': 3}).packageId, 3);
    expect(Booking.fromJson(bookingJson()).packageId, isNull);
  });

  testWidgets('a worker adds a package, pauses one and sees a hidden one', (tester) async {
    tall(tester);
    var list = [packageJson(1, withWorker: false), packageJson(2, title: 'Fan fitting', hidden: true,
        reason: 'Price looks wrong', withWorker: false)];
    final h = await pumpScreen(tester, const MyPackagesScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /workers/me/packages/', (_) => ok(list));
      h.backend.on('GET /workers/me/', (_) => ok(workerProfileJson()));
      h.backend.on('POST /workers/me/packages/', (req) {
        final created = {...packageJson(3, title: 'Wiring check', withWorker: false)};
        list = [...list, created];
        return ok(created, status: 201);
      });
      h.backend.on('PATCH /workers/me/packages/1/', (_) => ok(packageJson(1, active: false, withWorker: false)));
    });
    await tester.pumpAndSettle();
    expect(find.text('AC service'), findsOneWidget);
    expect(find.text('Hidden by KaamNow: Price looks wrong'), findsOneWidget);

    await tester.tap(find.byKey(const Key('package-active-1')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('PATCH /workers/me/packages/1/').single.body), {'is_active': false});

    await tester.tap(find.byKey(const Key('package-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('package-title')), 'Wiring check');
    await tester.enterText(find.byKey(const Key('package-price')), '1200');
    await tester.enterText(find.byKey(const Key('package-includes')), 'Check all sockets\n\nTest the DB box');
    await tester.tap(find.byKey(const Key('package-duration-120')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('package-save')));
    await tester.tap(find.byKey(const Key('package-save')));
    await tester.pumpAndSettle();
    final body = jsonDecode(h.backend.callsTo('POST /workers/me/packages/').single.body) as Map;
    expect(body['category'], 1, reason: 'the only service is picked for them');
    expect(body['title'], 'Wiring check');
    expect(body['price'], '1200');
    expect(body['duration_minutes'], 120);
    expect(body['includes'], ['Check all sockets', 'Test the DB box']);
    expect(find.text('Wiring check'), findsOneWidget);
  });

  testWidgets('the package form checks its fields before sending', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const PackageFormScreen(services: []), role: 'worker');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('package-title')), 'AC');
    await tester.enterText(find.byKey(const Key('package-includes')), List.filled(9, 'x').join('\n'));
    await tester.tap(find.byKey(const Key('package-save')));
    await tester.pumpAndSettle();
    expect(find.text('Title is too short.'), findsOneWidget);
    expect(find.text('Enter a price'), findsOneWidget);
    expect(find.text('List up to 8 things.'), findsOneWidget);
    expect(h.backend.callsTo('POST /workers/me/packages/'), isEmpty);
  });

  testWidgets('customers see a worker\'s packages and can book one', (tester) async {
    tall(tester);
    await pumpScreen(tester, const WorkerPublicScreen(id: 7), setup: (h) {
      h.backend.on('GET /workers/7/', (_) => ok(workerJson()));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([])));
      h.backend.on('GET /workers/7/packages/', (_) => ok([packageJson(3, booked: 5)]));
    });
    await tester.pumpAndSettle();
    expect(find.text('Fixed-price packages'), findsOneWidget);
    expect(find.text('AC service'), findsOneWidget);
    expect(find.text('Rs 2,500'), findsOneWidget);
    expect(find.text('Booked 5 times'), findsOneWidget);
    expect(find.byKey(const Key('package-book-3')), findsOneWidget);
  });

  testWidgets('a worker profile still opens when packages fail to load', (tester) async {
    tall(tester);
    await pumpScreen(tester, const WorkerPublicScreen(id: 7), setup: (h) {
      h.backend.on('GET /workers/7/', (_) => ok(workerJson()));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([])));
    });
    await tester.pumpAndSettle();
    expect(find.text('Bilal Ahmed'), findsWidgets);
    expect(find.text('Fixed-price packages'), findsNothing);
  });

  testWidgets('browse filters by category and the default address', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const PackagesScreen(), setup: (h) {
      h.backend.on('GET /services/categories/', (_) => ok(paged([
            {'id': 1, 'name': 'Electrician', 'slug': 'electrician', 'icon': '', 'is_active': true},
            {'id': 2, 'name': 'Plumber', 'slug': 'plumber', 'icon': '', 'is_active': true},
          ])));
      h.backend.on('GET /addresses/', (_) => ok([addressJson(isDefault: true)]));
      h.backend.on('GET /packages/', (req) => ok(paged(
          req.url.queryParameters['category'] == '2' ? [] : [packageJson(3)])));
    });
    await tester.pumpAndSettle();
    expect(find.text('AC service'), findsOneWidget);
    expect(find.text('Showing workers who come to Home'), findsOneWidget);
    final first = h.backend.callsTo('GET /packages/').first.url.queryParameters;
    expect(first['latitude'], startsWith('31.51'));
    expect(first['category'], isNull);
    await tester.tap(find.byKey(const Key('packages-cat-2')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('GET /packages/').last.url.queryParameters['category'], '2');
    expect(find.text('No packages here yet'), findsOneWidget);
  });

  group('booking a package', () {
    Future<Harness> setup(WidgetTester tester, {http409 = false}) async {
      tall(tester);
      final h = Harness(access: 'A', refresh: 'R');
      h.backend.on('GET /app/config/', (_) => ok(configJson()));
      h.backend.on('GET /auth/me/', (_) => ok(userJson()));
      h.backend.on('GET /packages/3/', (_) => ok(packageJson(3)));
      h.backend.on('GET /addresses/', (_) => ok([addressJson(isDefault: true), addressJson(id: 2, label: 'work')]));
      h.backend.on('GET /workers/7/slots/', (_) => ok(slotsJson()));
      h.backend.on('POST /packages/3/book/', (_) => http409
          ? err(409, 'worker_busy', 'This worker already has a booking at that time. Choose another offer.')
          : ok({...bookingJson(id: 40), 'package_id': 3}, status: 201));
      await h.session.restore();
      await tester.pumpWidget(host(h.session, '/packages/3/book', {
        '/packages/:id/book': (s) => BookPackageScreen(packageId: int.parse(s.pathParameters['id']!)),
        '/bookings/:id': (s) => Scaffold(body: Text('booking ${s.pathParameters['id']}')),
      }));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('picks a free slot and the default address, then opens the booking', (tester) async {
      final h = await setup(tester);
      expect(find.text('Total: Rs 2,500'), findsOneWidget);
      // A taken slot cannot be picked.
      final taken = tester.widget<ChoiceChip>(find.byKey(const Key('book-slot-9')));
      expect(taken.onSelected, isNull);
      await tester.tap(find.byKey(const Key('book-confirm')));
      await tester.pump();
      expect(find.text('Pick a time first.'), findsOneWidget);
      expect(h.backend.callsTo('POST /packages/3/book/'), isEmpty);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book-slot-11')));
      await tester.tap(find.byKey(const Key('book-addr-2')));
      await tester.enterText(find.byKey(const Key('book-notes')), 'Gate code 1234');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('book-confirm')));
      await tester.tap(find.byKey(const Key('book-confirm')));
      await tester.pumpAndSettle();
      final body = jsonDecode(h.backend.callsTo('POST /packages/3/book/').single.body) as Map;
      expect(body['saved_address'], 2);
      expect(body['notes'], 'Gate code 1234');
      expect(body.containsKey('latitude'), isFalse);
      final sent = DateTime.parse(body['preferred_time'] as String).toLocal();
      expect(sent.hour, 11);
      expect(find.text('booking 40'), findsOneWidget);
    });

    testWidgets('a clash shows the reason and reloads the slots', (tester) async {
      final h = await setup(tester, http409: true);
      await tester.tap(find.byKey(const Key('book-slot-13')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('book-confirm')));
      await tester.tap(find.byKey(const Key('book-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('already has a booking'), findsOneWidget);
      expect(h.backend.callsTo('GET /workers/7/slots/').length, 2);
      expect(find.text('booking 40'), findsNothing);
    });
  });

  testWidgets('a package booking is labelled on the booking page', (tester) async {
    tall(tester);
    await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      h.backend.on('GET /bookings/21/', (_) => ok({...bookingJson(), 'package_id': 3}));
      h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-package')), findsOneWidget);
    expect(find.text('Package price'), findsOneWidget);
  });

  testWidgets('admin hides a package with a reason', (tester) async {
    final h = await adminHarness();
    h.backend.on('GET /admin/packages/', (_) => ok(paged([packageJson(3, withWorker: false)])));
    h.backend.on('POST /admin/packages/3/hide/', (_) => ok(packageJson(3, hidden: true, reason: 'Misleading')));
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2000);
    await tester.tap(find.text('Service packages').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('AC service · Rs 2,500'), findsOneWidget);
    expect(h.backend.callsTo('GET /admin/packages/').first.url.queryParameters['is_hidden'], 'false');
    await tester.tap(find.byKey(const Key('admin-package-toggle-3')));
    await tester.pumpAndSettle();
    expect(find.text('Hide this package?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Misleading');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /admin/packages/3/hide/').single.body), {'reason': 'Misleading'});
  });
}
