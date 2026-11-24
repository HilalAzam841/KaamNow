import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/app.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Map<String, dynamic> smsConfig({bool required = true}) =>
    {...configJson(), 'phone_verification': {'required': required, 'sms_available': true}};

void main() {
  Harness customerHome({bool verified = false, bool required = true}) {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => ok(smsConfig(required: required)));
    h.backend.on('POST /auth/login/', (_) =>
        ok({'user': {...userJson(), 'phone_verified': verified}, 'tokens': {'access': 'A', 'refresh': 'R'}}));
    h.backend.on('GET /services/categories/', (_) => ok([]));
    h.backend.on('GET /notifications/unread-count/', (_) => ok({'unread': 0}));
    return h;
  }

  Future<void> logIn(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(KaamNowApp(session: h.session));
    await h.session.restore();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-phone')), '03001234567');
    await tester.enterText(find.byKey(const Key('login-password')), 'correct-horse');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a new user confirms their number with the SMS code before using the app', (tester) async {
    final h = customerHome();
    h.backend.on('POST /auth/phone/send-code/', (_) => ok({'detail': 'Code sent.', 'resend_after': 60, 'expires_in_minutes': 10}));
    h.backend.on('POST /auth/phone/verify/', (req) {
      final code = jsonDecode(req.body)['code'];
      if (code != '482913') return err(400, 'invalid_code', 'Wrong or expired code.');
      return ok({...userJson(), 'phone_verified': true});
    });
    await logIn(tester, h);

    expect(find.text('Confirm your phone number'), findsOneWidget);
    expect(find.text('Salam, Ayesha'), findsNothing);
    await tester.tap(find.byKey(const Key('verify-send')));
    await tester.pump();
    await tester.pump();
    expect(h.backend.callsTo('POST /auth/phone/send-code/'), hasLength(1));
    expect(find.text('Send a new code in 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Send a new code in 57s'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('verify-code')), '111111');
    await tester.tap(find.byKey(const Key('verify-confirm')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Wrong or expired code.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('verify-code')), '482913');
    await tester.tap(find.byKey(const Key('verify-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Salam, Ayesha'), findsOneWidget);
    expect(h.session.user!.phoneVerified, isTrue);
  });

  testWidgets('a confirmed number, or a server without the requirement, goes straight in', (tester) async {
    for (final h in [customerHome(verified: true), customerHome(required: false)]) {
      await logIn(tester, h);
      expect(find.text('Salam, Ayesha'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the verify screen can log out (wrong number)', (tester) async {
    final h = customerHome();
    h.backend.on('POST /auth/logout/', (_) => ok(null));
    await logIn(tester, h);
    await tester.tap(find.byKey(const Key('verify-logout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-phone')), findsOneWidget);
  });

  testWidgets('forgot password: SMS code, then a new password', (tester) async {
    final h = customerHome();
    h.backend.on('POST /auth/password-reset/', (_) => ok({'detail': 'If an account matches...', 'sms_code': true}));
    h.backend.on('POST /auth/password-reset/sms-confirm/', (_) => ok({'detail': 'Password has been reset.'}));
    await tester.pumpWidget(KaamNowApp(session: h.session));
    await h.session.restore();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-forgot')));
    await tester.pumpAndSettle();
    expect(find.text('Forgot your password?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('forgot-phone')), '0300 1234567');
    await tester.tap(find.byKey(const Key('forgot-send')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /auth/password-reset/').single.body), {'phone': '0300 1234567'});

    await tester.enterText(find.byKey(const Key('forgot-code')), '123456');
    await tester.enterText(find.byKey(const Key('forgot-password')), 'brand-new-77');
    await tester.enterText(find.byKey(const Key('forgot-confirm')), 'brand-new-77');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /auth/password-reset/sms-confirm/').single.body),
        {'phone': '0300 1234567', 'code': '123456', 'new_password': 'brand-new-77'});
    expect(find.text('Password changed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forgot-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-phone')), findsOneWidget);
  });

  testWidgets('forgot password without SMS on the server points to the email link', (tester) async {
    final h = customerHome(required: false);
    h.backend.on('POST /auth/password-reset/', (_) => ok({'detail': 'If an account matches...', 'sms_code': false}));
    await tester.pumpWidget(KaamNowApp(session: h.session));
    await h.session.restore();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-forgot')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('forgot-phone')), '03001234567');
    await tester.tap(find.byKey(const Key('forgot-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('emailed a link'), findsOneWidget);
    expect(find.byKey(const Key('forgot-code')), findsNothing);
  });
}
