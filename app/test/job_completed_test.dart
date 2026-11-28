import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> working({bool finished = false}) => {
      ...bookingJson(status: 'in_progress'),
      'worker_finished_at': finished ? '2026-11-28T10:00:00Z' : null,
      'auto_complete_at': finished ? '2026-11-29T10:00:00Z' : null,
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  void common(Harness h, Map<String, dynamic> Function() booking) {
    h.backend.on('GET /bookings/21/', (_) => ok(booking()));
    h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
    h.backend.on('GET /payments/', (_) => ok(paged([])));
    h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
  }

  test('finished and auto-complete times parse', () {
    final b = Booking.fromJson(working(finished: true));
    expect(b.workerFinishedAt, isNotNull);
    expect(b.autoCompleteAt!.toUtc(), DateTime.utc(2026, 11, 29, 10));
    expect(Booking.fromJson(bookingJson()).workerFinishedAt, isNull);
  });

  testWidgets('no completion code anywhere: the customer has one Job completed button', (tester) async {
    tall(tester);
    var status = 'in_progress';
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      common(h, () => status == 'completed' ? bookingJson(status: 'completed') : working());
      h.backend.on('POST /bookings/21/complete/', (_) {
        status = 'completed';
        return ok(bookingJson(status: 'completed'));
      });
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('issue-otp')), findsNothing);
    expect(find.textContaining('code'), findsNothing);
    expect(find.text('Job completed'), findsOneWidget);
    expect(find.byKey(const Key('not-finished')), findsNothing, reason: 'the worker has not said finished');

    await tester.ensureVisible(find.byKey(const Key('confirm-complete')));
    await tester.tap(find.byKey(const Key('confirm-complete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete').last);
    await tester.pumpAndSettle();
    final post = h.backend.callsTo('POST /bookings/21/complete/').single;
    expect(jsonDecode(post.body), {'confirm': true});
    expect(find.byKey(const Key('confirm-complete')), findsNothing);
  });

  testWidgets('the customer sees the worker finished and can say it is not done', (tester) async {
    tall(tester);
    var finished = true;
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      common(h, () => working(finished: finished));
      h.backend.on('POST /bookings/21/not-finished/', (_) {
        finished = false;
        return ok(working());
      });
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('says the work is finished'), findsOneWidget);
    expect(find.textContaining('completes on its own'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('not-finished')));
    await tester.tap(find.byKey(const Key('not-finished')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'The tap still leaks');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Send')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/not-finished/').single.body),
        {'reason': 'The tap still leaks'});
    expect(find.text('The worker has been told.'), findsOneWidget);
    expect(find.byKey(const Key('not-finished')), findsNothing);
    expect(find.byKey(const Key('confirm-complete')), findsOneWidget, reason: 'the customer can still complete');
  });

  testWidgets('the worker says finished, then can remind the customer', (tester) async {
    tall(tester);
    var finished = false;
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), role: 'worker', setup: (h) {
      common(h, () => working(finished: finished));
      h.backend.on('POST /bookings/21/finished/', (_) {
        finished = true;
        return ok(working(finished: true));
      });
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-otp')), findsNothing);
    expect(find.byKey(const Key('confirm-complete')), findsNothing, reason: 'only the customer completes');

    await tester.ensureVisible(find.byKey(const Key('worker-finished')));
    await tester.tap(find.byKey(const Key('worker-finished')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text("I've finished the job")));
    await tester.pumpAndSettle();
    expect(find.text('The customer has been asked to confirm.'), findsOneWidget);
    expect(find.byKey(const Key('waiting-customer-done')), findsOneWidget);
    expect(find.byKey(const Key('worker-finished')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('remind-customer')));
    await tester.tap(find.byKey(const Key('remind-customer')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /bookings/21/finished/'), hasLength(2));
    expect(find.text('Reminder sent.'), findsOneWidget);
  });
}
