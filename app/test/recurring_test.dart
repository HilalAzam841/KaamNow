import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/recurring/recurring_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> planJson({String status = 'active', String frequency = 'weekly', bool worker = true}) => {
      'id': 3,
      'title': 'Clean the AC',
      'description': 'Two split units',
      'category': 1,
      'category_name': 'AC repair',
      'address': 'House 1, Gulberg',
      'area': 'Gulberg',
      'duration_minutes': 120,
      'budget': '2000.00',
      'frequency': frequency,
      'next_visit': '2026-12-02T10:00:00Z',
      'status': status,
      'worker': worker ? {'id': 9, 'full_name': 'Bilal Ahmed'} : null,
      'source_booking': 21,
      'recent_visits': [
        {'id': 1, 'scheduled_for': '2026-11-25T10:00:00Z', 'outcome': 'all', 'note': '', 'request_id': 40,
          'booking_id': null},
      ],
      'created_at': '2026-11-20T10:00:00Z',
    };

Map<String, dynamic> workerPlanJson() => {
      'id': 3,
      'title': 'Clean the AC',
      'category': 1,
      'category_name': 'AC repair',
      'area': 'Gulberg',
      'duration_minutes': 120,
      'budget': '2000.00',
      'frequency': 'monthly',
      'next_visit': '2026-12-02T10:00:00Z',
      'status': 'active',
      'customer_name': 'Ayesha',
      'created_at': '2026-11-20T10:00:00Z',
    };

void big(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting());

  test('repeating job parses for the customer and the worker', () {
    final p = RecurringJob.fromJson(planJson());
    expect(p.workerName, 'Bilal Ahmed');
    expect(p.isActive, isTrue);
    expect(p.recentVisits.single.outcome, 'all');
    expect(p.recentVisits.single.requestId, 40);
    expect(RecurringJob.fromJson(planJson(worker: false)).workerName, isNull);
    final w = RecurringJob.fromJson(workerPlanJson());
    expect(w.customerName, 'Ayesha');
    expect(w.address, '');
  });

  test('the first repeat is one period after the booked visit and at least a day away', () {
    final now = DateTime(2026, 11, 25, 9);
    final booked = DateTime(2026, 11, 24, 15, 30);
    expect(defaultFirstVisit(booked, 'weekly', now: now), DateTime(2026, 12, 1, 15, 30));
    expect(defaultFirstVisit(booked, 'biweekly', now: now), DateTime(2026, 12, 8, 15, 30));
    expect(defaultFirstVisit(booked, 'monthly', now: now), DateTime(2026, 12, 24, 15, 30));
    // An old booking rolls forward.
    expect(defaultFirstVisit(DateTime(2026, 10, 1, 10), 'weekly', now: now), DateTime(2026, 11, 26, 10));
  });

  testWidgets('a customer repeats a booking every two weeks', (tester) async {
    big(tester);
    var created = false;
    final h = await pumpScreen(
      tester,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () async => created = await showRepeatJobSheet(context, Booking.fromJson(bookingJson())),
          child: const Text('open'),
        ),
      ),
      setup: (h) => h.backend.on('POST /recurring-jobs/from-booking/', (_) => ok(planJson(frequency: 'biweekly'))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat this job'), findsOneWidget);
    expect(find.textContaining('book-again request'), findsOneWidget);
    await tester.tap(find.byKey(const Key('freq-biweekly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-repeating')));
    await tester.pumpAndSettle();
    final body = jsonDecode(h.backend.callsTo('POST /recurring-jobs/from-booking/').single.body) as Map;
    expect(body['booking'], 21);
    expect(body['frequency'], 'biweekly');
    expect(DateTime.parse(body['first_visit'] as String).isAfter(DateTime.now()), isTrue);
    expect(created, isTrue);
  });

  testWidgets('a customer pauses, resumes and stops a repeating job', (tester) async {
    big(tester);
    var status = 'active';
    final h = await pumpScreen(tester, const RecurringJobsScreen(), setup: (h) {
      h.backend.on('GET /recurring-jobs/', (_) => ok({'count': 1, 'next': null, 'results': [planJson(status: status)]}));
      for (final a in ['pause', 'resume', 'cancel', 'skip-next']) {
        h.backend.on('POST /recurring-jobs/3/$a/', (_) {
          status = {'pause': 'paused', 'resume': 'active', 'cancel': 'cancelled'}[a] ?? status;
          return ok(planJson(status: status));
        });
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Clean the AC'), findsOneWidget);
    expect(find.text('With Bilal Ahmed'), findsOneWidget);
    expect(find.byKey(const Key('next-visit-3')), findsOneWidget);
    expect(find.text('Sent to workers nearby'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-menu-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /recurring-jobs/3/pause/'), hasLength(1));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byKey(const Key('next-visit-3')), findsNothing);

    await tester.tap(find.byKey(const Key('resume-3')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /recurring-jobs/3/resume/'), hasLength(1));

    await tester.tap(find.byKey(const Key('plan-menu-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop repeating').last);
    await tester.pumpAndSettle();
    expect(find.text('Stop repeating this job?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Stop repeating'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /recurring-jobs/3/cancel/'), hasLength(1));
    expect(find.text('No repeating jobs'), findsOneWidget);
  });

  testWidgets('a customer changes how often it repeats', (tester) async {
    big(tester);
    final h = await pumpScreen(tester, const RecurringJobsScreen(), setup: (h) {
      h.backend.on('GET /recurring-jobs/', (_) => ok({'count': 1, 'next': null, 'results': [planJson()]}));
      h.backend.on('PATCH /recurring-jobs/3/', (_) => ok(planJson(frequency: 'monthly')));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-menu-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change how often'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-freq-monthly')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('PATCH /recurring-jobs/3/').single.body), {'frequency': 'monthly'});
  });

  testWidgets('a worker sees no address and can step away', (tester) async {
    big(tester);
    var left = false;
    final h = await pumpScreen(tester, const RecurringJobsScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /recurring-jobs/',
          (_) => ok({'count': left ? 0 : 1, 'next': null, 'results': left ? [] : [workerPlanJson()]}));
      h.backend.on('POST /recurring-jobs/3/leave/', (_) {
        left = true;
        return ok(workerPlanJson());
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('Ayesha · Gulberg'), findsOneWidget);
    expect(find.textContaining('Every month'), findsOneWidget);
    expect(find.byKey(const Key('plan-menu-3')), findsNothing);
    await tester.tap(find.byKey(const Key('leave-3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayesha will be told'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'I cannot do this any more'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /recurring-jobs/3/leave/'), hasLength(1));
    expect(find.text('When a customer repeats a job with you, it shows here.'), findsOneWidget);
  });
}
