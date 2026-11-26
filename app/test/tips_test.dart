import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/admin/tips_screen.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:kaamnow/ui/worker/tips_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> tipJson({String status = 'pending', String method = 'cash', String message = ''}) => {
      'id': 4, 'booking': 21, 'booking_title': 'Fan not working', 'customer_name': 'Ayesha', 'worker_name': 'Bilal Ahmed',
      'amount': '200.00', 'method': method, 'message': message, 'status': status, 'payment_id': 40,
      'paid_at': status == 'paid' ? '2026-11-26T10:00:00Z' : null, 'created_at': '2026-11-26T09:00:00Z',
    };

Map<String, dynamic> doneBooking({Map<String, dynamic>? tip, bool canTip = true}) => {
      ...bookingJson(status: 'completed'),
      'tip': tip == null ? null : {'id': 4, 'amount': tip['amount'], 'method': tip['method'], 'status': tip['status'],
          'message': tip['message']},
      'can_tip': canTip,
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('tip, booking and config parse', () {
    final b = Booking.fromJson(doneBooking(tip: tipJson(message: 'Thanks')));
    expect(b.canTip, isTrue);
    expect(b.tip!.isPending && b.tip!.isCash, isTrue);
    expect(b.tip!.message, 'Thanks');
    expect(Booking.fromJson(bookingJson()).tip, isNull);
    expect(Booking.fromJson(bookingJson()).canTip, isFalse);
    final cfg = ClientConfig.fromJson({...configJson(), 'tips': {'enabled': true, 'min': '50.00', 'max': '1000.00',
        'window_days': 3, 'suggestions': ['100.00', '200.00']}});
    expect(cfg.tips.max, '1000.00');
    expect(cfg.tips.suggestions, ['100.00', '200.00']);
    expect(ClientConfig.fromJson(configJson()).tips.enabled, isTrue);
  });

  Future<Harness> openBooking(WidgetTester tester, Map<String, dynamic> booking, {String role = 'customer'}) async {
    tall(tester);
    return pumpScreen(tester, const BookingDetailScreen(id: 21), role: role, setup: (h) {
      h.backend.on('GET /bookings/21/', (_) => ok(booking));
      h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
      h.backend.on('GET /payments/', (_) => ok(paged([])));
      h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
      h.backend.on('POST /bookings/21/tip/', (_) => ok({'tip': tipJson(), 'checkout': null}, status: 201));
      h.backend.on('POST /tips/4/confirm-cash/', (_) => ok(tipJson(status: 'paid')));
    });
  }

  testWidgets('a customer tips in cash with a suggested amount and a note', (tester) async {
    final h = await openBooking(tester, doneBooking());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('give-tip')));
    await tester.tap(find.byKey(const Key('give-tip')));
    await tester.pumpAndSettle();
    expect(find.text('Say thanks with a tip'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tip-amount-200.00')));
    await tester.enterText(find.byKey(const Key('tip-message')), 'Great work');
    await tester.pump();
    await tester.tap(find.byKey(const Key('tip-send')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/tip/').single.body),
        {'amount': '200.00', 'method': 'cash', 'message': 'Great work'});
    expect(find.text('Thanks! The worker will confirm they got the cash.'), findsOneWidget);
  });

  testWidgets('a custom amount outside the limits is refused', (tester) async {
    final h = await openBooking(tester, doneBooking());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('give-tip')));
    await tester.tap(find.byKey(const Key('give-tip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tip-other')), '10');
    await tester.pump();
    await tester.tap(find.byKey(const Key('tip-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter Rs'), findsOneWidget);
    expect(h.backend.callsTo('POST /bookings/21/tip/'), isEmpty);
    await tester.enterText(find.byKey(const Key('tip-other')), '750');
    await tester.pump();
    await tester.tap(find.byKey(const Key('tip-send')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/tip/').single.body)['amount'], '750');
  });

  testWidgets('no tip button once tipped or when the window closed', (tester) async {
    await openBooking(tester, doneBooking(tip: tipJson(status: 'paid'), canTip: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('give-tip')), findsNothing);
    expect(find.text('You tipped Rs 200. Thank you!'), findsOneWidget);
  });

  testWidgets('the worker confirms a cash tip', (tester) async {
    final h = await openBooking(tester, doneBooking(tip: tipJson(message: 'Shukriya'), canTip: false), role: 'worker');
    await tester.pumpAndSettle();
    expect(find.text('The customer says they gave you a cash tip of Rs 200.'), findsOneWidget);
    expect(find.text('“Shukriya”'), findsOneWidget);
    expect(find.byKey(const Key('give-tip')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('tip-got-it')));
    await tester.tap(find.byKey(const Key('tip-got-it')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /tips/4/confirm-cash/'), hasLength(1));
  });

  test('an online tip returns the checkout', () async {
    final h = Harness(access: 'A');
    h.backend.on('POST /bookings/21/tip/', (_) => ok({
          'tip': tipJson(method: 'jazzcash'),
          'checkout': {'url': 'https://sandbox.jazzcash.com.pk/pay', 'method': 'POST', 'fields': {'a': '1'}},
        }, status: 201));
    final (tip, checkout) = await h.api.giveTip(21, amount: '200', method: 'jazzcash');
    expect(tip.method, 'jazzcash');
    expect(checkout!.url, 'https://sandbox.jazzcash.com.pk/pay');
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/tip/').single.body), {'amount': '200', 'method': 'jazzcash'});
  });

  testWidgets('the worker sees their tips and the total', (tester) async {
    tall(tester);
    await pumpScreen(tester, const TipsScreen(), role: 'worker', setup: (h) {
      h.backend.on('GET /tips/summary/', (_) => ok({'count': 1, 'total': '200.00'}));
      h.backend.on('GET /tips/', (_) => ok(paged([tipJson(status: 'paid', message: 'Great work')])));
    });
    await tester.pumpAndSettle();
    expect(find.text('Tips received: 1 · Total Rs 200'), findsOneWidget);
    expect(find.text('Rs 200 · Ayesha'), findsOneWidget);
    expect(find.textContaining('“Great work”'), findsOneWidget);
  });

  testWidgets('admin lists tips', (tester) async {
    final h = await adminHarness();
    h.backend.on('GET /admin/tips/', (_) => ok(paged([{...tipJson(status: 'paid'), 'customer_name': 'Ayesha Khan'}])));
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2000);
    await tester.tap(find.text('Tips').first);
    await tester.pumpAndSettle();
    expect(find.byType(AdminTipsScreen), findsOneWidget);
    expect(find.textContaining('Rs 200 · Ayesha Khan → Bilal Ahmed'), findsOneWidget);
    expect(h.backend.callsTo('GET /admin/tips/').first.url.queryParameters['status'], 'paid');
  });
}
