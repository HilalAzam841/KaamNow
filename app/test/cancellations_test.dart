import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:kaamnow/ui/customer/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;
import 'widget_flows_test.dart' show host;

Map<String, dynamic> feeJson({String status = 'owed', String reason = 'late'}) =>
    {'id': 5, 'amount': '200.00', 'worker_share': '180.00', 'status': status, 'reason': reason};

Map<String, dynamic> cancelledBooking({String status = 'owed'}) => {
      ...bookingJson(status: 'cancelled'),
      'cancel_reason': 'Plans changed',
      'cancellation_fee': feeJson(status: status),
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('fee and quote parse', () {
    final b = Booking.fromJson(cancelledBooking());
    expect(b.cancellationFee!.isOwed, isTrue);
    expect(b.cancellationFee!.workerShare, '180.00');
    expect(Booking.fromJson(bookingJson()).cancellationFee, isNull);
    final q = CancellationQuote.fromJson({'fee': '0.00', 'reason': null, 'free_until': '2026-11-26T10:00:00Z',
        'fee_after': '200.00'});
    expect(q.isFree, isTrue);
    expect(q.feeAfter, '200.00');
    expect(CancellationQuote.fromJson({'fee': '300.00', 'reason': 'on_the_way'}).isFree, isFalse);
  });

  Future<Harness> openBooking(WidgetTester tester, Map<String, dynamic> booking,
      {String role = 'customer', Map<String, dynamic>? quote}) async {
    tall(tester);
    return pumpScreen(tester, const BookingDetailScreen(id: 21), role: role, setup: (h) {
      h.backend.on('GET /bookings/21/', (_) => ok(booking));
      h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
      h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
      if (quote != null) h.backend.on('GET /bookings/21/cancel-fee/', (_) => ok(quote));
      h.backend.on('POST /bookings/21/cancel/', (_) => ok(cancelledBooking()));
    });
  }

  testWidgets('the cancel dialog says what cancelling late costs', (tester) async {
    final h = await openBooking(tester, bookingJson(),
        quote: {'fee': '200.00', 'reason': 'late', 'free_until': null, 'fee_after': null});
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cancel-booking')));
    await tester.tap(find.byKey(const Key('cancel-booking')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancelling now costs Rs 200'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Plans changed');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/cancel/').single.body), {'reason': 'Plans changed'});
  });

  testWidgets('the cancel dialog says until when it is free', (tester) async {
    await openBooking(tester, bookingJson(),
        quote: {'fee': '0.00', 'reason': null, 'free_until': '2026-11-26T10:00:00Z', 'fee_after': '200.00'});
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cancel-booking')));
    await tester.tap(find.byKey(const Key('cancel-booking')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancelling is free until'), findsOneWidget);
    expect(find.textContaining('After that it costs Rs 200'), findsOneWidget);
  });

  testWidgets('the cancel dialog still opens when the fee check fails', (tester) async {
    await openBooking(tester, bookingJson());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cancel-booking')));
    await tester.tap(find.byKey(const Key('cancel-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this booking?'), findsWidgets);
    expect(find.byKey(const Key('prompt-message')), findsNothing);
  });

  testWidgets('a customer sees the owed fee, with no online payment yet', (tester) async {
    await openBooking(tester, cancelledBooking());
    await tester.pumpAndSettle();
    expect(find.textContaining('Late cancellation fee: Rs 200'), findsOneWidget);
    expect(find.textContaining('Pay at the KaamNow office'), findsOneWidget);
    expect(find.byKey(const Key('fee-pay-jazzcash')), findsNothing);
  });

  testWidgets('with JazzCash on, the customer gets a pay button', (tester) async {
    tall(tester);
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('GET /app/config/', (_) => ok({
          ...configJson(),
          'payment_methods': [
            {'code': 'cash', 'label': 'Cash', 'available': true},
            {'code': 'jazzcash', 'label': 'JazzCash', 'available': true},
          ],
        }));
    h.backend.on('GET /auth/me/', (_) => ok(userJson()));
    h.backend.on('GET /bookings/21/', (_) => ok(cancelledBooking()));
    h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
    await h.session.restore();
    await tester.pumpWidget(host(h.session, '/bookings/21', {
      '/bookings/:id': (s) => BookingDetailScreen(id: int.parse(s.pathParameters['id']!)),
    }));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fee-pay-jazzcash')), findsOneWidget);
    expect(find.byKey(const Key('fee-pay-cash')), findsNothing);
  });

  testWidgets('the worker sees their share, then that it was paid', (tester) async {
    await openBooking(tester, cancelledBooking(), role: 'worker');
    await tester.pumpAndSettle();
    expect(find.text('You get Rs 180 once the customer pays the late cancellation fee.'), findsOneWidget);
  });

  testWidgets('a paid or waived fee shows as settled', (tester) async {
    await openBooking(tester, cancelledBooking(status: 'waived'));
    await tester.pumpAndSettle();
    expect(find.text('The cancellation fee was waived.'), findsOneWidget);
  });

  test('pay calls the server and returns the checkout', () async {
    final h = Harness(access: 'A');
    h.backend.on('POST /cancellation-fees/5/pay/', (_) => ok({
          'id': 9, 'amount': '200.00', 'status': 'pending',
          'checkout': {'url': 'https://sandbox.jazzcash.com.pk/pay', 'method': 'POST', 'fields': {'a': '1'}},
        }, status: 201));
    final checkout = await h.api.payCancellationFee(5, 'jazzcash');
    expect(checkout!.url, 'https://sandbox.jazzcash.com.pk/pay');
    expect(jsonDecode(h.backend.callsTo('POST /cancellation-fees/5/pay/').single.body), {'method': 'jazzcash'});
  });

  testWidgets('the home banner shows an owed fee', (tester) async {
    tall(tester);
    await pumpScreen(tester, const OwedFeeBanner(), setup: (h) {
      h.backend.on('GET /cancellation-fees/', (_) => ok(paged([
            {...feeJson(), 'booking': 21, 'booking_title': 'Fan not working'}
          ])));
    });
    await tester.pumpAndSettle();
    expect(find.text('You owe a late cancellation fee of Rs 200'), findsOneWidget);
  });

  testWidgets('admin waives a fee with a reason', (tester) async {
    final h = await adminHarness();
    Map<String, dynamic> adminFee(String status) => {
          ...feeJson(status: status), 'booking': 21, 'booking_title': 'Fan not working', 'customer': 3,
          'customer_name': 'Ayesha Khan', 'worker': 7, 'worker_name': 'Bilal Ahmed', 'commission_percent': '10.00',
          'waived_reason': status == 'waived' ? 'Worker agreed' : '', 'created_at': '2026-11-26T08:00:00Z',
        };
    h.backend.on('GET /admin/cancellation-fees/', (_) => ok(paged([adminFee('owed')])));
    h.backend.on('POST /admin/cancellation-fees/5/waive/', (_) => ok(adminFee('waived')));
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2000);
    await tester.tap(find.text('Cancellation fees').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Rs 200 · Ayesha Khan · booking #21'), findsOneWidget);
    expect(h.backend.callsTo('GET /admin/cancellation-fees/').first.url.queryParameters['status'], 'owed');
    await tester.tap(find.byKey(const Key('admin-fee-waive-5')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Worker agreed');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Waive'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /admin/cancellation-fees/5/waive/').single.body),
        {'reason': 'Worker agreed'});
  });
}
