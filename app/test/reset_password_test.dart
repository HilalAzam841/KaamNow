import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/ui/auth/reset_password_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  Future<Harness> pump(WidgetTester tester, {String uid = 'MQ', String token = 'tok-1'}) async {
    final h = Harness();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: h.session,
      child: MaterialApp(home: ResetPasswordScreen(uid: uid, token: token)),
    ));
    return h;
  }

  testWidgets('sets a new password with the uid and token from the email link', (tester) async {
    final h = await pump(tester);
    h.backend.on('POST /auth/password-reset/confirm/', (_) => ok(null));
    await tester.enterText(find.byKey(const Key('reset-password')), 'new-pass-123');
    await tester.enterText(find.byKey(const Key('reset-confirm')), 'different');
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pump();
    expect(find.text('The passwords do not match'), findsOneWidget);
    expect(h.backend.calls, isEmpty);

    await tester.enterText(find.byKey(const Key('reset-confirm')), 'new-pass-123');
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pumpAndSettle();
    final body = jsonDecode(h.backend.callsTo('POST /auth/password-reset/confirm/').single.body);
    expect(body, {'uid': 'MQ', 'token': 'tok-1', 'new_password': 'new-pass-123'});
    expect(find.text('Password changed'), findsOneWidget);
  });

  testWidgets('shows the server error for an expired link', (tester) async {
    final h = await pump(tester);
    h.backend.on('POST /auth/password-reset/confirm/', (_) => err(400, 'invalid', 'Invalid or expired reset link.'));
    await tester.enterText(find.byKey(const Key('reset-password')), 'new-pass-123');
    await tester.enterText(find.byKey(const Key('reset-confirm')), 'new-pass-123');
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid or expired reset link.'), findsOneWidget);
  });

  testWidgets('an incomplete link says so instead of showing the form', (tester) async {
    await pump(tester, token: '');
    expect(find.text('This reset link is incomplete'), findsOneWidget);
    expect(find.byKey(const Key('reset-submit')), findsNothing);
  });
}
