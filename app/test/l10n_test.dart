import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/core/format.dart';
import 'package:kaamnow/core/locale_controller.dart';
import 'package:kaamnow/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness;
import 'helpers.dart';

class MemoryLanguageStore implements LanguageStore {
  MemoryLanguageStore([this.value]);
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String code) async => value = code;
}

TextDirection directionOf(WidgetTester tester, Finder f) => Directionality.of(tester.element(f));

void customerRoutes(Harness h, {String language = 'en'}) {
  h.backend.on('GET /app/config/', (_) => ok(configJson()));
  h.backend.on('GET /auth/me/', (_) => ok({...userJson(), 'language': language}));
  h.backend.on('PATCH /auth/me/', (req) => ok({...userJson(), ...jsonDecode(req.body) as Map<String, dynamic>}));
  h.backend.on('GET /services/categories/', (_) => ok([
        {'id': 1, 'name': 'برقی کاریگر', 'slug': 'electrician', 'description': '', 'icon': '', 'is_active': true, 'sort_order': 1},
      ]));
  h.backend.on('GET /notifications/unread-count/', (_) => ok({'unread': 0}));
}

void main() {
  tearDown(() => useStrings(lookupAppLocalizations(const Locale('en'))));

  testWidgets('the language button on the login screen switches to Urdu, right to left, and remembers it',
      (tester) async {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    final store = MemoryLanguageStore();
    final locale = LocaleController(store: store);
    await tester.pumpWidget(KaamNowApp(session: h.session, locale: locale));
    await h.session.restore();
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
    expect(directionOf(tester, find.byKey(const Key('login-phone'))), TextDirection.ltr);

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('لاگ اِن'), findsWidgets);
    expect(find.text('Log in'), findsNothing);
    expect(directionOf(tester, find.byKey(const Key('login-phone'))), TextDirection.rtl);
    expect(store.value, 'ur');
    expect(h.client.language, 'ur');

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsWidgets);
    expect(store.value, 'en');
  });

  testWidgets('requests carry the chosen language and the account is updated to match', (tester) async {
    final h = Harness(access: 'A', refresh: 'R');
    customerRoutes(h, language: 'en');
    final locale = LocaleController(initial: 'ur', store: MemoryLanguageStore('ur'));
    await tester.pumpWidget(KaamNowApp(session: h.session, locale: locale));
    await h.session.restore();
    await tester.pumpAndSettle();

    expect(find.text('السلام علیکم، Ayesha'), findsOneWidget);
    expect(find.text('برقی کاریگر'), findsOneWidget);
    final categories = h.backend.callsTo('GET /services/categories/').last;
    expect(categories.headers['Accept-Language'], 'ur');

    final patches = h.backend.callsTo('PATCH /auth/me/');
    expect(patches, hasLength(1), reason: 'the saved language is sent once');
    expect(jsonDecode(patches.single.body), {'language': 'ur'});
  });

  testWidgets('an account already in Urdu is not updated again', (tester) async {
    final h = Harness(access: 'A', refresh: 'R');
    customerRoutes(h, language: 'ur');
    final locale = LocaleController(initial: 'ur');
    await tester.pumpWidget(KaamNowApp(session: h.session, locale: locale));
    await h.session.restore();
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('PATCH /auth/me/'), isEmpty);
  });

  testWidgets('the admin dashboard stays in English even when Urdu is picked', (tester) async {
    final h = await adminHarness();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KaamNowApp(session: h.session, locale: LocaleController(initial: 'ur')));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsWidgets);
    expect(h.client.language, 'en');
    expect(h.backend.calls.where((r) => r.method == 'PATCH'), isEmpty);
  });

  test('amounts, statuses and relative times follow the language', () {
    useStrings(lookupAppLocalizations(const Locale('ur')));
    expect(rs('1800.00'), '1,800 روپے');
    expect(statusLabel('completed'), isNot('Completed'));
    useStrings(lookupAppLocalizations(const Locale('en')));
    expect(rs('1800.00'), 'Rs 1,800');
    expect(statusLabel('completed'), 'Completed');
  });
}
