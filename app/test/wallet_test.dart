import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaamnow/core/locale_controller.dart';
import 'package:kaamnow/l10n/l10n.dart';
import 'package:kaamnow/ui/worker/earnings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'admin_test.dart' show pumpAdmin, adminHarness, paged;
import 'helpers.dart';

Map<String, dynamic> earningsJson() => {
      'completed_jobs': 3,
      'gross_amount': '6000.00',
      'commission_amount': '600.00',
      'net_earnings': '5400.00',
      'commission_pending': '100.00',
      'current_commission_percent': '10.00',
      'recent': [],
    };

Map<String, dynamic> settlementJson({String kind = 'payout', String status = 'requested', String amount = '1700.00'}) => {
      'id': 9,
      'worker': 5,
      'worker_name': 'Bilal Ahmed',
      'worker_phone': '+923210599243',
      'kind': kind,
      'status': status,
      'amount': amount,
      'earnings_amount': '1800.00',
      'commission_amount': '100.00',
      'method': 'jazzcash',
      'account_title': 'Bilal Ahmed',
      'account_number': '03001234567',
      'reference': '',
      'note': '',
      'payment': null,
      'bookings': [21, 22],
      'processed_at': null,
      'created_at': '2026-11-25T10:00:00+05:00',
    };

Map<String, dynamic> walletJson({
  String held = '1800.00',
  String owed = '100.00',
  String balance = '1700.00',
  bool canRequest = true,
  bool blocked = false,
  Map<String, dynamic>? open,
  Map<String, dynamic>? last,
  List<Map<String, dynamic>> history = const [],
}) =>
    {
      'earnings_held': held,
      'commission_owed': owed,
      'balance': balance,
      'min_payout': '500.00',
      'commission_debt_limit': '5000.00',
      'can_request_payout': canRequest,
      'must_pay_commission': balance.startsWith('-'),
      'offers_blocked': blocked,
      'open_settlement': open,
      'last_payout_account': last,
      'settlements': history,
    };

Future<Harness> pumpEarnings(WidgetTester tester, Map<String, dynamic> Function() wallet,
    {List<Map<String, dynamic>> methods = const []}) async {
  final h = Harness(access: 'A', refresh: 'R');
  h.backend.on('GET /app/config/', (_) => ok({
        ...configJson(),
        if (methods.isNotEmpty) 'payment_methods': methods,
      }));
  h.backend.on('GET /auth/me/', (_) => ok(userJson(role: 'worker')));
  h.backend.on('GET /payments/earnings/', (_) => ok(earningsJson()));
  h.backend.on('GET /payments/wallet/', (_) => ok(wallet()));
  await h.session.restore();
  final router = GoRouter(initialLocation: '/', routes: [GoRoute(path: '/', builder: (_, _) => const EarningsScreen())]);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: h.session),
      ChangeNotifierProvider(create: (_) => LocaleController()),
    ],
    child: MaterialApp.router(localizationsDelegates: AppLocalizations.localizationsDelegates, routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('worker wallet', () {
    testWidgets('shows what KaamNow owes and asks for a payout to JazzCash', (tester) async {
      var requested = false;
      final h = await pumpEarnings(
          tester, () => requested ? walletJson(balance: '0.00', held: '0.00', owed: '0.00', open: settlementJson()) : walletJson());
      h.backend.on('POST /payments/payouts/', (_) {
        requested = true;
        return ok(settlementJson(), status: 201);
      });
      expect(find.text('KaamNow owes you'), findsOneWidget);
      expect(find.text('Rs 1,700'), findsOneWidget);
      expect(find.text('From online payments: Rs 1,800'), findsOneWidget);
      expect(find.text('Commission on cash jobs: Rs 100'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wallet-get-paid')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payout-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(2));
      await tester.enterText(find.byKey(const Key('payout-title')), 'Bilal Ahmed');
      await tester.enterText(find.byKey(const Key('payout-number')), '03001234567');
      await tester.tap(find.byKey(const Key('payout-submit')));
      await tester.pumpAndSettle();

      expect(jsonDecode(h.backend.callsTo('POST /payments/payouts/').single.body),
          {'method': 'jazzcash', 'account_title': 'Bilal Ahmed', 'account_number': '03001234567'});
      expect(find.text('Payout of Rs 1,700 requested'), findsOneWidget);
      expect(find.byKey(const Key('wallet-get-paid')), findsNothing);
    });

    testWidgets('an open payout request can be cancelled', (tester) async {
      var open = true;
      final h = await pumpEarnings(tester, () => walletJson(open: open ? settlementJson() : null));
      h.backend.on('POST /payments/payouts/9/cancel/', (_) {
        open = false;
        return ok(settlementJson(status: 'cancelled'));
      });
      await tester.tap(find.byKey(const Key('wallet-cancel-payout')));
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('POST /payments/payouts/9/cancel/'), hasLength(1));
      expect(find.byKey(const Key('wallet-get-paid')), findsOneWidget);
    });

    testWidgets('below the minimum there is no payout button', (tester) async {
      await pumpEarnings(tester, () => walletJson(balance: '300.00', held: '300.00', owed: '0.00', canRequest: false));
      expect(find.byKey(const Key('wallet-get-paid')), findsNothing);
      expect(find.text('You can ask for a payout from Rs 500.'), findsOneWidget);
    });

    testWidgets('owing commission offers online payment and warns when offers are blocked', (tester) async {
      final h = await pumpEarnings(tester,
          () => walletJson(balance: '-5200.00', held: '0.00', owed: '5200.00', canRequest: false, blocked: true),
          methods: [
            {'code': 'cash', 'label': 'Cash', 'available': true},
            {'code': 'jazzcash', 'label': 'JazzCash', 'available': true},
          ]);
      h.backend.on('POST /payments/commission/pay/', (_) => ok({
            'settlement': settlementJson(kind: 'collection', amount: '5200.00'),
            'payment': {'id': 3, 'amount': '5200.00', 'checkout': null},
          }, status: 201));
      expect(find.text('You owe KaamNow'), findsOneWidget);
      expect(find.byKey(const Key('wallet-offers-blocked')), findsOneWidget);
      expect(find.byKey(const Key('wallet-pay-cash')), findsNothing);
      await tester.tap(find.byKey(const Key('wallet-pay-jazzcash')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /payments/commission/pay/').single.body), {'method': 'jazzcash'});
    });

    testWidgets('lists past payouts', (tester) async {
      await pumpEarnings(tester, () => walletJson(history: [
            {...settlementJson(status: 'completed'), 'reference': 'JC-778899'},
          ]));
      await tester.scrollUntilVisible(find.byKey(const Key('settlement-9')), 200);
      expect(find.textContaining('JC-778899'), findsOneWidget);
    });
  });

  group('admin payouts', () {
    testWidgets('marks a payout paid with the transfer reference', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/settlements/', (_) => ok(paged([settlementJson()])));
      h.backend.on('POST /admin/settlements/9/mark-paid/', (_) => ok(settlementJson(status: 'completed')));
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Payouts').first);
      await tester.pumpAndSettle();
      expect(find.text('Bilal Ahmed · Rs 1,700'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mark-paid-9')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('payout-reference')), 'JC-778899');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/settlements/9/mark-paid/').single.body),
          {'reference': 'JC-778899'});
      final query = h.backend.callsTo('GET /admin/settlements/').first.url.queryParameters;
      expect(query['kind'], 'payout');
      expect(query['status'], 'requested');
    });

    testWidgets('records commission a worker handed in', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/settlements/', (_) => ok(paged([])));
      h.backend.on('GET /admin/worker-balances/', (_) => ok([
            {'worker': 5, 'worker_name': 'Bilal Ahmed', 'worker_phone': '+923210599243', 'earnings_held': '0.00',
             'commission_owed': '300.00', 'balance': '-300.00'}
          ]));
      h.backend.on('POST /admin/workers/5/record-commission/',
          (_) => ok(settlementJson(kind: 'collection', status: 'completed', amount: '300.00'), status: 201));
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Payouts').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owe commission'));
      await tester.pumpAndSettle();
      expect(find.text('Bilal Ahmed owes Rs 300'), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-5')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('commission-reference')), 'Receipt 0042');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/workers/5/record-commission/').single.body),
          {'method': 'cash', 'reference': 'Receipt 0042'});
      expect(h.backend.callsTo('GET /admin/worker-balances/').first.url.queryParameters['owing'], 'true');
    });
  });
}
