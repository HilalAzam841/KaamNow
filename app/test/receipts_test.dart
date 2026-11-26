import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:kaamnow/ui/payments/receipt_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;
import 'refunds_test.dart' show paymentJson;
import 'widget_flows_test.dart' show host;

Map<String, dynamic> receiptJson({String status = 'completed', List<Map<String, dynamic>> refunds = const [],
        String tax = '', String label = 'Job price'}) =>
    {
      'number': 'KN20261126ABCDE',
      'issued_at': '2026-11-26T06:00:00Z',
      'status': status,
      'purpose': 'booking',
      'booking': 21,
      'title': 'Fan not working',
      'service': 'Electrician',
      'billed_to': 'Ayesha Khan',
      'worker': 'Bilal Ahmed',
      'method': 'jazzcash',
      'method_label': 'JazzCash',
      'transaction_id': 'T123456789012',
      'lines': [
        {'label': label, 'amount': '2000.00'},
        {'label': 'Discount (EID20)', 'amount': '-200.00'},
      ],
      'total': '1800.00',
      'refunds': refunds,
      'refunded': refunds.isEmpty ? '0.00' : '500.00',
      'net_paid': refunds.isEmpty ? '1800.00' : '1300.00',
      'company': 'KaamNow',
      'company_address': 'Lahore, Pakistan',
      'tax_number': tax,
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('a receipt parses', () {
    final r = Receipt.fromJson(receiptJson(refunds: [
      {'date': '2026-11-27', 'amount': '500.00', 'reference': 'JC-RF-1'}
    ]));
    expect(r.bookingId, 21);
    expect(r.lines.map((l) => l.amount), ['2000.00', '-200.00']);
    expect(r.refunds.single.date, DateTime(2026, 11, 27));
    expect(signedRs('-200.00'), '-Rs 200');
    expect(signedRs('2000.00'), 'Rs 2,000');
  });

  testWidgets('the receipt shows each line, the total and refunds', (tester) async {
    tall(tester);
    await pumpScreen(tester, const ReceiptScreen(paymentId: 31), setup: (h) {
      h.backend.on('GET /payments/31/receipt/', (_) => ok(receiptJson(tax: 'NTN 1234567-8', refunds: [
            {'date': '2026-11-27', 'amount': '500.00', 'reference': 'JC-RF-1'}
          ])));
    });
    await tester.pumpAndSettle();
    expect(find.text('Lahore, Pakistan'), findsOneWidget);
    expect(find.text('Tax number: NTN 1234567-8'), findsOneWidget);
    expect(find.text('Discount (EID20)'), findsOneWidget);
    expect(find.text('-Rs 200'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('receipt-total'))).data, 'Rs 1,800');
    expect(find.text('Refund on 27 Nov 2026'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('receipt-net'))).data, 'Rs 1,300');
    expect(find.text('Bilal Ahmed'), findsOneWidget);
  });

  testWidgets('the PDF downloads in the app language', (tester) async {
    tall(tester);
    (Uint8List, String, String)? saved;
    final h = await pumpScreen(tester, ReceiptScreen(
      paymentId: 31,
      save: (bytes, name, type) async {
        saved = (bytes, name, type);
        return true;
      },
    ), setup: (h) {
      h.backend.on('GET /payments/31/receipt/', (req) => ok(receiptJson(
          label: req.headers['Accept-Language']?.startsWith('ur') == true ? 'کام کی قیمت' : 'Job price')));
      h.backend.on('GET /payments/31/receipt/pdf/', (req) => http.Response.bytes([37, 80, 68, 70], 200,
          headers: {'content-type': 'application/pdf'}));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receipt-pdf')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('GET /payments/31/receipt/pdf/').single.url.queryParameters, {'lang': 'en'});
    expect(saved!.$2, 'kaamnow-receipt-KN20261126ABCDE.pdf');
    expect(saved!.$3, 'application/pdf');
    expect(String.fromCharCodes(saved!.$1), '%PDF');
    expect(find.text('Receipt downloaded.'), findsOneWidget);

  });

  testWidgets('a paid booking links to its receipt', (tester) async {
    tall(tester);
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    h.backend.on('GET /auth/me/', (_) => ok(userJson()));
    await h.session.restore();
    h.backend.on('GET /bookings/21/', (_) => ok(bookingJson(status: 'completed')));
    h.backend.on('GET /payments/', (_) => ok(paged([paymentJson()])));
    h.backend.on('GET /requests/11/', (_) => ok(requestJson()));
    await tester.pumpWidget(host(h.session, '/bookings/21', {
      '/bookings/:id': (s) => BookingDetailScreen(id: int.parse(s.pathParameters['id']!)),
      '/payments/:id/receipt': (s) => Text('receipt ${s.pathParameters['id']}'),
    }));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('payment-receipt')));
    await tester.tap(find.byKey(const Key('payment-receipt')));
    await tester.pumpAndSettle();
    expect(find.text('receipt 31'), findsOneWidget);
  });
}
