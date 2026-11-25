import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/core/locale_controller.dart';
import 'package:kaamnow/l10n/l10n.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/account/invite_screen.dart';
import 'package:kaamnow/ui/auth/register_screen.dart';
import 'package:kaamnow/ui/bookings/promo_box.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'admin_test.dart' show pumpAdmin, adminHarness, paged;
import 'helpers.dart';

Map<String, dynamic> quoteJson({String code = '', String promo = '0.00', String balance = '0.00', String credit = '0.00'}) {
  final discount = double.parse(promo) + double.parse(credit);
  return {
    'total': '2000.00',
    'promo_code': code,
    'promo_description': '',
    'promo_discount': promo,
    'credit_balance': balance,
    'credit_used': credit,
    'discount': discount.toStringAsFixed(2),
    'amount': (2000 - discount).toStringAsFixed(2),
    'max_discount': '1000.00',
  };
}

Future<Harness> pumpScreen(WidgetTester tester, Widget screen,
    {String role = 'customer', void Function(Harness h)? setup}) async {
  final h = Harness(access: 'A', refresh: 'R');
  setup?.call(h);
  h.backend.on('GET /app/config/', (_) => ok(configJson()));
  h.backend.on('GET /auth/me/', (_) => ok(userJson(role: role)));
  await h.session.restore();
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => Scaffold(body: screen))]);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: h.session),
      ChangeNotifierProvider(create: (_) => LocaleController()),
    ],
    child: MaterialApp.router(localizationsDelegates: AppLocalizations.localizationsDelegates, routerConfig: router),
  ));
  return h;
}

void main() {
  test('payment quote and discount parse', () {
    final q = PaymentQuote.fromJson(quoteJson(code: 'EID20', promo: '300.00', balance: '100.00', credit: '100.00'));
    expect(q.hasPromo && q.hasCredit && q.usesCredit && q.hasDiscount, isTrue);
    expect(q.amount, '1600.00');
    expect(Payment.fromJson({'id': 1, 'amount': '1600.00', 'discount_amount': '400.00'}).hasDiscount, isTrue);
  });

  test('an invite link keeps its code through the splash screen', () async {
    final h = Harness();
    expect(redirectFor(h.session, '/register?ref=AB12CDE'), '/splash?from=%2Fregister%3Fref%3DAB12CDE');
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    await h.session.restore();
    expect(redirectFor(h.session, '/splash?from=%2Fregister%3Fref%3DAB12CDE'), '/register?ref=AB12CDE');
    expect(redirectFor(h.session, '/register?ref=AB12CDE'), isNull);
  });

  testWidgets('promo box applies a code, uses credit and reports the choice', (tester) async {
    DiscountChoice? choice;
    await pumpScreen(tester, Builder(builder: (_) => PromoBox(bookingId: 21, onChanged: (d) => choice = d)),
        setup: (h) => h.backend.on('POST /promos/check/', (req) {
      final b = jsonDecode(req.body) as Map;
      if (b['promo_code'] == 'BAD') return err(400, 'promo_invalid', 'This promo code has expired.');
      final code = b['promo_code'] == 'EID20' ? 'EID20' : '';
      return ok(quoteJson(
          code: code,
          promo: code.isEmpty ? '0.00' : '300.00',
          balance: '100.00',
          credit: b['use_credit'] == true ? '100.00' : '0.00'));
    }));
    await tester.pumpAndSettle();
    expect(find.text('Use my credit (Rs 100)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('promo-code')), 'BAD');
    await tester.tap(find.byKey(const Key('promo-apply')));
    await tester.pumpAndSettle();
    expect(find.text('This promo code has expired.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('promo-code')), 'EID20');
    await tester.tap(find.byKey(const Key('promo-apply')));
    await tester.pumpAndSettle();
    expect(find.text('EID20: Rs 300 off'), findsOneWidget);
    expect(find.text('You pay Rs 1,700'), findsOneWidget);

    await tester.tap(find.byKey(const Key('use-credit')));
    await tester.pumpAndSettle();
    expect(find.text('You pay Rs 1,600'), findsOneWidget);
    expect(choice?.promoCode, 'EID20');
    expect(choice?.useCredit, isTrue);

    await tester.tap(find.byKey(const Key('promo-remove')));
    await tester.pumpAndSettle();
    expect(choice?.promoCode, '');
    expect(find.text('You pay Rs 1,900'), findsOneWidget);
  });

  testWidgets('invite screen shows the code and copies the invite', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await pumpScreen(tester, const InviteScreen(), setup: (h) => h.backend.on('GET /referrals/me/', (_) => ok({
          'code': 'AB12CDE',
          'invite_link': 'https://kaamnow.pk/#/register?ref=AB12CDE',
          'credit_balance': '200.00',
          'invited': 2,
          'rewarded': 1,
          'rewards_earned': '200.00',
          'referral_reward': '200.00',
          'welcome_credit': '100.00',
          'min_booking': '500.00',
          'credit_history': [
            {'id': 5, 'amount': '200.00', 'kind': 'referral', 'note': 'Sana Iqbal', 'created_at': '2026-11-25T10:00:00+05:00'},
            {'id': 4, 'amount': '-100.00', 'kind': 'spent', 'note': 'Booking #21', 'created_at': '2026-11-24T10:00:00+05:00'},
          ],
        })));
    await tester.pumpAndSettle();
    expect(find.text('AB12CDE'), findsOneWidget);
    expect(find.text('Friends who joined: 2'), findsOneWidget);
    expect(find.text('Your credit: Rs 200'), findsOneWidget);
    expect(find.text('Invite reward'), findsOneWidget);
    expect(find.text('−Rs 100'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-copy')));
    await tester.pumpAndSettle();
    expect(copied, contains('AB12CDE'));
    expect(copied, contains('https://kaamnow.pk/#/register?ref=AB12CDE'));
    expect(find.text('Invite copied. Paste it in WhatsApp or SMS.'), findsOneWidget);
  });

  testWidgets('sign-up from an invite link sends the code', (tester) async {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    await h.session.restore();
    Map? sent;
    h.backend.on('POST /auth/register/', (req) {
      sent = jsonDecode(req.body) as Map;
      return err(400, 'validation_error', 'Invalid input.', {'referral_code': ['This invite code does not exist.']});
    });
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const RegisterScreen(referralCode: 'AB12CDE'))]);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: h.session),
        ChangeNotifierProvider(create: (_) => LocaleController()),
      ],
      child: MaterialApp.router(localizationsDelegates: AppLocalizations.localizationsDelegates, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('AB12CDE'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reg-name')), 'Sana Iqbal');
    await tester.enterText(find.byKey(const Key('reg-phone')), '03001234567');
    await tester.enterText(find.byKey(const Key('reg-password')), 'longpassword');
    await tester.ensureVisible(find.byKey(const Key('reg-submit')));
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(sent?['referral_code'], 'AB12CDE');
    expect(find.text('This invite code does not exist.'), findsOneWidget);
  });

  group('admin promo codes', () {
    Map<String, dynamic> promoJson({bool active = true}) => {
          'id': 3, 'code': 'EID20', 'description': 'Eid offer', 'kind': 'percent', 'value': '20.00',
          'max_discount': '300.00', 'min_order': '500.00', 'category': null, 'category_name': null,
          'starts_at': null, 'ends_at': null, 'max_uses': 100, 'max_uses_per_user': 1,
          'first_booking_only': false, 'is_active': active, 'uses': 7, 'discount_given': '2100.00',
        };

    testWidgets('lists codes with their use and creates one', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/promo-codes/', (_) => ok(paged([promoJson()])));
      h.backend.on('GET /services/categories/', (_) => ok(paged([])));
      h.backend.on('POST /admin/promo-codes/', (_) => ok(promoJson(), status: 201));
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Promo codes').first);
      await tester.pumpAndSettle();
      expect(find.text('EID20 · 20% off (up to Rs 300)'), findsOneWidget);
      expect(find.text('Used 7 times · Rs 2,100 given'), findsOneWidget);
      expect(h.backend.callsTo('GET /admin/promo-codes/').first.url.queryParameters['is_active'], 'true');

      await tester.tap(find.byKey(const Key('new-promo')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('promo-code-field')), 'ramzan');
      await tester.enterText(find.byKey(const Key('promo-value')), '150');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      expect(find.text('At most 100'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('promo-value')), '25');
      await tester.enterText(find.byKey(const Key('promo-max-discount')), '400');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await tester.pumpAndSettle();
      final body = jsonDecode(h.backend.callsTo('POST /admin/promo-codes/').single.body) as Map;
      expect(body['code'], 'RAMZAN');
      expect(body['kind'], 'percent');
      expect(body['value'], '25');
      expect(body['max_discount'], '400');
      expect(body['max_uses_per_user'], 1);
    });

    testWidgets('switches a code off', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/promo-codes/', (_) => ok(paged([promoJson()])));
      h.backend.on('PATCH /admin/promo-codes/3/', (_) => ok(promoJson(active: false)));
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Promo codes').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-promo-3')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('PATCH /admin/promo-codes/3/').single.body), {'is_active': false});
    });
  });
}
