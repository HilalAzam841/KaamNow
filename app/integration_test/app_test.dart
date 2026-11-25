// Runs the real app on an Android or iPhone device, emulator or simulator against a real KaamNow server that has the
// demo accounts (python manage.py seed_demo_data). From the Android emulator the computer is
// 10.0.2.2; from the iPhone simulator it is localhost:
//
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart \
//     --dart-define=API_BASE_URL=http://10.0.2.2:8000
//
// Screenshots land in build/android-shots/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kaamnow/main.dart' as app;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const demoPassword = 'KaamNow-Demo-2026';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  Future<void> tapAndWait(WidgetTester tester, Finder target, Finder expected) async {
    await tester.tap(target);
    await waitFor(tester, expected);
  }

  var shotsReady = false;
  Future<void> shot(WidgetTester tester, String name) async {
    if (!shotsReady) {
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage(); // iOS needs no conversion
      shotsReady = true;
    }
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot(name);
  }

  Future<void> logIn(WidgetTester tester, String phone) async {
    await waitFor(tester, find.byKey(const Key('login-phone')));
    await tester.enterText(find.byKey(const Key('login-phone')), phone);
    await tester.enterText(find.byKey(const Key('login-password')), demoPassword);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byKey(const Key('login-submit')));
  }

  Future<void> logOut(WidgetTester tester) async {
    await tapAndWait(tester, find.text('Account').last, find.byKey(const Key('account-invite')));
    // On a phone screen the worker's account list is longer than the screen.
    await tester.scrollUntilVisible(find.byKey(const Key('logout')), 200,
        scrollable: find.ancestor(of: find.byKey(const Key('account-invite')), matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const Key('logout')));
    await waitFor(tester, find.byKey(const Key('login-phone')));
  }

  testWidgets('customer and worker journeys on the phone app', (tester) async {
    (await SharedPreferences.getInstance()).clear();
    await app.main();
    await waitFor(tester, find.byKey(const Key('login-phone')));
    await shot(tester, 'android-01-login');

    // Customer: signs in, sees the services from the server.
    await logIn(tester, '03000000002');
    await waitFor(tester, find.text('Salam, Ayesha'));
    await waitFor(tester, find.text('Electrician'));
    // Browser-only cards are not shown in the phone app.
    expect(find.byKey(const Key('push-banner')), findsNothing);
    expect(find.byKey(const Key('install-banner')), findsNothing);
    await shot(tester, 'android-02-customer-home');

    // Account screen, then Urdu and back.
    await tapAndWait(tester, find.text('Account').last, find.text('Log out'));
    expect(find.byKey(const Key('push-switch')), findsNothing);
    await tapAndWait(tester, find.byKey(const Key('language-menu')).hitTestable().first, find.byKey(const Key('language-ur')));
    await tapAndWait(tester, find.byKey(const Key('language-ur')), find.text('لاگ آؤٹ'));
    await shot(tester, 'android-03-account-urdu');
    await tapAndWait(tester, find.byKey(const Key('language-menu')).hitTestable().first, find.byKey(const Key('language-en')));
    await tapAndWait(tester, find.byKey(const Key('language-en')), find.text('Log out'));
    await logOut(tester);

    // Worker: signs in and lands on the job feed.
    await logIn(tester, '03001000001');
    await waitFor(tester, find.text('Jobs near you'));
    await shot(tester, 'android-04-worker-feed');
    await logOut(tester);
  });
}
