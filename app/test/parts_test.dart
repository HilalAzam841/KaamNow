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
import 'job_photos_test.dart' show png;
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> partJson(int id,
        {String name = 'Breaker', int qty = 1, String price = '850.00', String status = 'pending',
        String reason = '', bool receipt = false}) =>
    {
      'id': id, 'booking': 21, 'name': name, 'quantity': qty, 'unit_price': price,
      'total': (double.parse(price) * qty).toStringAsFixed(2), 'status': status, 'reject_reason': reason,
      'receipt_url': receipt ? '/api/v1/bookings/21/parts/$id/receipt/' : null,
      'decided_at': null, 'created_at': '2026-11-28T10:00:00Z',
    };

Map<String, dynamic> partsSummary(
        {String approved = '0.00', int pending = 0, int count = 0, bool canAdd = false, bool canDecide = false}) =>
    {'approved_total': approved, 'pending': pending, 'count': count, 'can_add': canAdd, 'can_decide': canDecide};

Map<String, dynamic> withParts(Map<String, dynamic> booking, Map<String, dynamic> summary, {String amount = '0.00'}) =>
    {...booking, 'parts': summary, 'parts_amount': amount};

void main() {
  setUpAll(() => initializeDateFormatting());

  test('booking parts summary and parts parse', () {
    final b = Booking.fromJson(withParts(bookingJson(), partsSummary(approved: '850.00', count: 2, pending: 1),
        amount: '850.00'));
    expect(b.partsAmount, '850.00');
    expect((b.parts.count, b.parts.pending, b.parts.canAdd), (2, 1, false));
    final old = Booking.fromJson(bookingJson());
    expect((old.partsAmount, old.parts.count), ('0.00', 0), reason: 'older servers send no parts');
    final p = JobPart.fromJson(partJson(3, qty: 2, receipt: true));
    expect((p.total, p.isPending, p.receiptUrl), ('1700.00', true, '/api/v1/bookings/21/parts/3/receipt/'));
  });

  void common(Harness h, Map<String, dynamic> booking) {
    h.backend.on('GET /bookings/21/', (_) => ok(booking));
    h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
    h.backend.on('GET /payments/', (_) => ok(paged([])));
    h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
    h.backend.on('GET /bookings/21/parts/3/receipt/',
        (_) => http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}));
  }

  testWidgets('the worker adds a part with a receipt photo', (tester) async {
    tall(tester);
    final parts = <Map<String, dynamic>>[];
    final h = await pumpScreen(
      tester,
      BookingDetailScreen(
          id: 21, photoPicker: () async => UploadFile(field: 'image', filename: 'receipt.jpg', bytes: Uint8List(8))),
      role: 'worker',
      setup: (h) {
        common(h, withParts(bookingJson(status: 'in_progress'), partsSummary(canAdd: true)));
        h.backend.on('GET /bookings/21/parts/', (_) =>
            ok({'summary': partsSummary(count: parts.length, pending: parts.length, canAdd: true), 'results': parts}));
        h.backend.on('POST /bookings/21/parts/', (req) {
          parts.add(partJson(3, qty: 2, receipt: true));
          return ok(parts.last, status: 201);
        });
        h.backend.on('DELETE /bookings/21/parts/3/', (_) {
          parts.clear();
          return http.Response('', 204);
        });
      },
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-parts')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-part')));
    await tester.tap(find.byKey(const Key('add-part')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('part-submit'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('part-name')), 'Breaker');
    await tester.enterText(find.byKey(const Key('part-qty')), '2');
    await tester.enterText(find.byKey(const Key('part-price')), '850');
    await tester.pump();
    expect(find.text('Total: Rs 1,700'), findsOneWidget);
    await tester.tap(find.byKey(const Key('part-pick-receipt')));
    await tester.pumpAndSettle();
    expect(find.text('Receipt photo added'), findsOneWidget);
    await tester.tap(find.byKey(const Key('part-submit')));
    await tester.pumpAndSettle();

    final post = h.backend.callsTo('POST /bookings/21/parts/').single;
    final body = utf8.decode(post.bodyBytes, allowMalformed: true);
    expect(body, contains('name="name"\r\n\r\nBreaker'));
    expect(body, contains('name="quantity"\r\n\r\n2'));
    expect(body, contains('name="unit_price"\r\n\r\n850.00'));
    expect(body, contains('name="receipt"; filename="receipt.jpg"'));
    expect(find.byKey(const Key('part-3')), findsOneWidget);
    expect(find.text('Waiting for the customer'), findsOneWidget);
    expect(find.byKey(const Key('approve-part-3')), findsNothing, reason: 'the worker cannot approve');

    await tester.ensureVisible(find.byKey(const Key('remove-part-3')));
    await tester.tap(find.byKey(const Key('remove-part-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('DELETE /bookings/21/parts/3/'), hasLength(1));
    expect(find.byKey(const Key('part-3')), findsNothing);
  });

  testWidgets('the customer approves one part and rejects another before paying', (tester) async {
    tall(tester);
    var parts = [partJson(3, receipt: true), partJson(4, name: 'Wire', price: '400.00')];
    var amount = '0.00';
    Map<String, dynamic> summary() => partsSummary(
          approved: amount,
          count: parts.length,
          pending: parts.where((p) => p['status'] == 'pending').length,
          canDecide: true,
        );
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      h.backend.on('GET /bookings/21/', (_) =>
          ok(withParts({...bookingJson(status: 'completed'), 'total_amount': '${2500 + double.parse(amount)}'},
              summary(), amount: amount)));
      h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
      h.backend.on('GET /payments/', (_) => ok(paged([])));
      h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
      h.backend.on('GET /bookings/21/parts/3/receipt/',
          (_) => http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}));
      h.backend.on('GET /bookings/21/parts/', (_) => ok({'summary': summary(), 'results': parts}));
      h.backend.on('POST /bookings/21/parts/3/approve/', (_) {
        parts = [partJson(3, status: 'approved', receipt: true), parts[1]];
        amount = '850.00';
        return ok(parts[0]);
      });
      h.backend.on('POST /bookings/21/parts/4/reject/', (req) {
        parts = [parts[0], partJson(4, name: 'Wire', price: '400.00', status: 'rejected', reason: 'Too costly')];
        return ok(parts[1]);
      });
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parts-pending')), findsOneWidget);
    expect(find.text('2 parts are waiting for you. Approve or reject them before paying.'), findsOneWidget);
    expect(find.byKey(const Key('add-part')), findsNothing, reason: 'customers do not add parts');

    await tester.ensureVisible(find.byKey(const Key('part-receipt-3')));
    await tester.tap(find.byKey(const Key('part-receipt-3')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(h.backend.callsTo('GET /bookings/21/parts/3/receipt/'), hasLength(1));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('approve-part-3')));
    await tester.tap(find.byKey(const Key('approve-part-3')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /bookings/21/parts/3/approve/'), hasLength(1));
    expect(find.text('Approved'), findsOneWidget);
    expect(find.byKey(const Key('parts-total')), findsOneWidget);
    expect(find.text('Parts and materials'), findsWidgets);
    expect(find.text('Rs 3,350'), findsWidgets, reason: 'the booking total now includes the part');

    await tester.ensureVisible(find.byKey(const Key('reject-part-4')));
    await tester.tap(find.byKey(const Key('reject-part-4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Too costly');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reject')));
    await tester.pumpAndSettle();
    final reject = h.backend.callsTo('POST /bookings/21/parts/4/reject/').single;
    expect(jsonDecode(reject.body), {'reason': 'Too costly'});
    expect(find.text('Reason: Too costly'), findsOneWidget);
    expect(find.byKey(const Key('parts-pending')), findsNothing);
  });

  testWidgets('no parts section when there are none and nothing to add', (tester) async {
    tall(tester);
    final h = await pumpScreen(tester, const BookingDetailScreen(id: 21), setup: (h) {
      common(h, withParts(bookingJson(status: 'confirmed'), partsSummary()));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-parts')), findsNothing);
    expect(h.backend.callsTo('GET /bookings/21/parts/'), isEmpty);
  });
}
