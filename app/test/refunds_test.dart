import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/models/admin_models.dart';
import 'package:kaamnow/models/models.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show pumpAdmin, adminHarness, paged;
import 'helpers.dart';

Map<String, dynamic> paymentJson({
  int id = 31,
  String status = 'completed',
  String method = 'jazzcash',
  String refunded = '0.00',
  String refundable = '2000.00',
  List<Map<String, dynamic>> refunds = const [],
  String failure = '',
}) =>
    {
      'id': id,
      'purpose': 'booking',
      'booking': 21,
      'amount': '2000.00',
      'method': method,
      'status': status,
      'reference': 'KN20261125ABCDE',
      'failure_reason': failure,
      'expires_at': null,
      'confirmed_at': null,
      'refunded_amount': refunded,
      'created_at': '2026-11-25T10:00:00+05:00',
      'updated_at': '2026-11-25T10:00:00+05:00',
      'payer': 3,
      'payer_name': 'Ayesha Khan',
      'payer_phone': '+923001112233',
      'worker_name': 'Bilal Ahmed',
      'gateway_transaction_id': 'T2026112500001',
      'refundable_amount': refundable,
      'refunds': refunds,
    };

Future<void> openPayments(WidgetTester tester, Harness h) async {
  await pumpAdmin(tester, h);
  await tester.tap(find.text('Payments').first);
  await tester.pumpAndSettle();
}

void main() {
  test('payments carry the refunded amount', () {
    final p = Payment.fromJson(paymentJson(refunded: '500.00'));
    expect(p.hasRefund, isTrue);
    expect(p.refundedAmount, '500.00');
    expect(Payment.fromJson({...paymentJson(), 'refunded_amount': null}).hasRefund, isFalse);
    final a = AdminPayment.fromJson(paymentJson(refundable: '0.00', refunds: [
      {'id': 4, 'amount': '2000.00', 'worker_share': '0.00', 'method': 'gateway', 'reason': 'x', 'reference': 'R'}
    ]));
    expect(a.canRefund, isFalse);
    expect(a.refunds.single.reference, 'R');
  });

  group('admin payments', () {
    testWidgets('lists disputed payments first and accepts one', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/payments/', (_) => ok(paged([
            paymentJson(status: 'disputed', refundable: '0.00', failure: 'Gateway reported success after the payment was closed.')
          ])));
      h.backend.on('POST /admin/payments/31/resolve/', (_) => ok(paymentJson()));
      await openPayments(tester, h);
      expect(h.backend.callsTo('GET /admin/payments/').first.url.queryParameters['status'], 'disputed');
      expect(find.text('Ayesha Khan · Rs 2,000 · JazzCash'), findsOneWidget);
      expect(find.textContaining('T2026112500001'), findsOneWidget);
      await tester.tap(find.byKey(const Key('accept-31')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('resolve-note')), 'Found in JazzCash portal');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/payments/31/resolve/').single.body),
          {'resolution': 'accept', 'note': 'Found in JazzCash portal'});
    });

    testWidgets('records the refund of a disputed payment with its reference', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/payments/', (_) => ok(paged([paymentJson(status: 'disputed', refundable: '0.00')])));
      h.backend.on('POST /admin/payments/31/resolve/', (_) => ok(paymentJson(status: 'refunded', refunded: '2000.00')));
      await openPayments(tester, h);
      await tester.tap(find.byKey(const Key('resolve-refund-31')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('resolve-reference')), 'JC-RF-2001');
      await tester.enterText(find.byKey(const Key('resolve-note')), 'Paid twice');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/payments/31/resolve/').single.body),
          {'resolution': 'refund', 'note': 'Paid twice', 'method': 'gateway', 'reference': 'JC-RF-2001'});
    });

    testWidgets('refunds part of a completed payment and charges the worker', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/payments/', (_) => ok(paged([paymentJson()])));
      h.backend.on('POST /admin/payments/31/refund/', (_) => ok({
            'id': 4, 'payment': 31, 'amount': '500.00', 'worker_share': '450.00', 'method': 'gateway',
            'reason': 'Leak came back', 'reference': 'JC-RF-1001', 'complaint': null,
          }, status: 201));
      await openPayments(tester, h);
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('GET /admin/payments/').last.url.queryParameters['status'], 'completed');
      await tester.tap(find.byKey(const Key('refund-31')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('refund-amount')), '2500');
      await tester.enterText(find.byKey(const Key('refund-reference')), 'JC-RF-1001');
      await tester.enterText(find.byKey(const Key('refund-reason')), 'Leak came back');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(find.text('At most Rs 2,000'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('refund-amount')), '500');
      await tester.tap(find.byKey(const Key('refund-charge-worker')));
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/payments/31/refund/').single.body), {
        'amount': '500',
        'method': 'gateway',
        'reason': 'Leak came back',
        'reference': 'JC-RF-1001',
        'charge_worker': true,
      });
      expect(find.text('Refund recorded.'), findsOneWidget);
    });

    testWidgets('refunded filter shows past refunds', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/payments/', (_) => ok(paged([
            paymentJson(refunded: '500.00', refundable: '1500.00', refunds: [
              {'id': 4, 'amount': '500.00', 'worker_share': '450.00', 'method': 'gateway', 'reason': 'Leak came back',
               'reference': 'JC-RF-1001'}
            ])
          ])));
      await openPayments(tester, h);
      await tester.tap(find.text('Refunded'));
      await tester.pumpAndSettle();
      final q = h.backend.callsTo('GET /admin/payments/').last.url.queryParameters;
      expect(q['refunded'], 'true');
      expect(q.containsKey('status'), isFalse);
      expect(find.textContaining('Refunded Rs 500 via JazzCash / Easypaisa portal · Ref JC-RF-1001'), findsOneWidget);
      expect(find.textContaining('worker paid Rs 450'), findsOneWidget);
    });
  });
}
