import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/core/format.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/customer/new_request_screen.dart';
import 'package:kaamnow/ui/customer/worker_public_screen.dart';
import 'package:kaamnow/ui/worker/schedule_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> scheduleJson({List<Map<String, dynamic>> hours = const [], List<Map<String, dynamic>> off = const []}) =>
    {'hours': hours, 'time_off': off};

void main() {
  setUpAll(() => initializeDateFormatting());

  test('availability models parse', () {
    final s = WorkerSchedule.fromJson(scheduleJson(hours: [
      {'weekday': 0, 'start': '09:00', 'end': '17:00'}
    ], off: [
      {'id': 3, 'start_date': '2026-12-01', 'end_date': '2026-12-03', 'reason': 'Wedding'}
    ]));
    expect(s.hours.single.toJson(), {'weekday': 0, 'start': '09:00', 'end': '17:00'});
    expect(s.timeOff.single.endDate, DateTime(2026, 12, 3));
    final slot = TimeSlot.fromJson({'start': '2026-12-01T05:00:00Z', 'end': '2026-12-01T07:00:00Z', 'free_workers': 2});
    expect(slot.end.difference(slot.start), const Duration(hours: 2));
    expect(ServiceRequest.fromJson({'id': 1, 'status': 'open'}).durationMinutes, 120);
    expect(ServiceRequest.fromJson({'id': 1, 'status': 'open', 'duration_minutes': 240}).durationMinutes, 240);
    expect(PublicWorker.fromJson({'id': 1, 'full_name': 'A'}).workingHours, isEmpty);
  });

  test('time window and duration labels', () {
    expect(whenWindow(DateTime(2026, 12, 1, 10), 120), '1 Dec, 10:00 AM to 12:00 PM');
    expect(durationLabel(60), '1 hour');
    expect(durationLabel(240), '4 hours');
    expect(durationLabel(90), '1 h 30 min');
    expect(whenWindow(null, 120), '');
  });

  testWidgets('worker sets working days and hours and saves them', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await pumpScreen(tester, const ScheduleScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /workers/me/schedule/', (_) => ok(scheduleJson()));
      h.backend.on('PUT /workers/me/schedule/', (req) => ok(scheduleJson(hours: [
            for (final row in (jsonDecode(req.body) as Map)['hours'] as List) (row as Map).cast<String, dynamic>()
          ])));
    });
    await tester.pumpAndSettle();
    expect(find.text('Available any time'), findsOneWidget);
    // Switch to set hours: Monday to Saturday 9 to 6 is the starting point.
    await tester.tap(find.byKey(const Key('schedule-any-time')));
    await tester.pumpAndSettle();
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Day off'), findsOneWidget); // Sunday
    // Saturday off too.
    await tester.tap(find.byKey(const Key('schedule-day-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save')));
    await tester.pumpAndSettle();
    final body = jsonDecode(h.backend.callsTo('PUT /workers/me/schedule/').single.body) as Map;
    final hours = body['hours'] as List;
    expect([for (final r in hours) r['weekday']], [0, 1, 2, 3, 4]);
    expect(hours.first, {'weekday': 0, 'start': '09:00', 'end': '18:00'});
    expect(find.text('Working hours saved.'), findsOneWidget);
  });

  testWidgets('worker sees and removes days off', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var removed = false;
    final h = await pumpScreen(tester, const ScheduleScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /workers/me/schedule/', (_) => ok(scheduleJson(
          hours: [{'weekday': 2, 'start': '10:00', 'end': '14:00'}],
          off: removed ? [] : [{'id': 7, 'start_date': '2026-12-01', 'end_date': '2026-12-03', 'reason': 'Wedding'}])));
      h.backend.on('DELETE /workers/me/time-off/7/', (_) {
        removed = true;
        return ok(null);
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('Available any time'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('1 Dec 2026 to 3 Dec 2026'), findsOneWidget);
    expect(find.text('Wedding'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('time-off-7')), matching: find.byIcon(Icons.delete_outline)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('DELETE /workers/me/time-off/7/'), hasLength(1));
    expect(find.text('No days off planned.'), findsOneWidget);
  });

  testWidgets('customer picks a time slot with free workers and a job length', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    DateTime at(int hour) => DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour);
    final h = await pumpScreen(tester, const NewRequestScreen(categoryId: 1, initialPin: LatLng(31.51, 74.34)),
        setup: (h) {
      h.backend.on('GET /services/categories/', (_) => ok(paged([
            {'id': 1, 'name': 'Electrician', 'slug': 'electrician', 'is_active': true}
          ])));
      h.backend.on('GET /requests/slots/', (_) => ok([
            {'start': at(10).toUtc().toIso8601String(), 'end': at(12).toUtc().toIso8601String(), 'free_workers': 3},
            {'start': at(12).toUtc().toIso8601String(), 'end': at(14).toUtc().toIso8601String(), 'free_workers': 0},
          ]));
      h.backend.on('POST /requests/', (_) => ok({'id': 5, 'status': 'open', 'matched_workers_count': 3}, status: 201));
    });
    await tester.pumpAndSettle();
    final slotCall = h.backend.callsTo('GET /requests/slots/').last;
    expect(slotCall.url.queryParameters['category'], '1');
    expect(slotCall.url.queryParameters['date'], isNotEmpty);
    expect(find.text('10:00 AM · 3 free'), findsOneWidget);
    expect(find.text('12:00 PM · none free'), findsOneWidget);

    await tester.tap(find.byKey(const Key('slot-10')));
    await tester.pumpAndSettle();
    expect(find.textContaining('10:00 AM to 12:00 PM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('req-duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 hours').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('10:00 AM to 2:00 PM'), findsOneWidget);
  });

  testWidgets('a worker profile shows working hours', (tester) async {
    await pumpScreen(tester, const WorkerPublicScreen(id: 4), setup: (h) {
      h.backend.on('GET /workers/4/', (_) => ok({
            'id': 4,
            'full_name': 'Bilal Ahmed',
            'working_hours': [{'weekday': 0, 'start': '09:00', 'end': '17:00'}],
          }));
      h.backend.on('GET /workers/4/reviews/', (_) => ok(paged([])));
    });
    await tester.pumpAndSettle();
    expect(find.text('Monday: 9:00 AM to 5:00 PM'), findsOneWidget);
  });
}
