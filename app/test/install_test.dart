import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/core/install/install_controller.dart';
import 'package:kaamnow/core/install/install_platform.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class FakeInstallPlatform implements InstallPlatform {
  FakeInstallPlatform({this.canPrompt = false, this.isIos = false, this.isStandalone = false, this.accept = true});
  @override
  bool canPrompt;
  @override
  bool isIos;
  @override
  bool isStandalone;
  final bool accept;
  int prompts = 0;
  void Function()? _onChange;

  @override
  Future<bool> prompt() async {
    prompts++;
    canPrompt = false;
    if (accept) isStandalone = true;
    return accept;
  }

  @override
  void listen(void Function() onChange) => _onChange = onChange;

  /// The browser fires `beforeinstallprompt` after the page has loaded.
  void offer() {
    canPrompt = true;
    _onChange?.call();
  }
}

Future<Harness> pumpCustomer(WidgetTester tester, InstallController install) async {
  final h = Harness(access: 'A', refresh: 'R');
  h.backend.on('GET /app/config/', (_) => ok(configJson()));
  h.backend.on('GET /auth/me/', (_) => ok(userJson()));
  h.backend.on('GET /services/categories/', (_) => ok([
        {'id': 1, 'name': 'Electrician', 'slug': 'electrician', 'description': '', 'icon': '', 'is_active': true, 'sort_order': 1},
      ]));
  h.backend.on('GET /notifications/unread-count/', (_) => ok({'unread': 0}));
  await tester.pumpWidget(KaamNowApp(session: h.session, install: install));
  await h.session.restore();
  await tester.pumpAndSettle();
  return h;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the install banner appears when the browser offers it and installs with one tap', (tester) async {
    final platform = FakeInstallPlatform();
    await pumpCustomer(tester, InstallController(platform: platform));
    expect(find.byKey(const Key('install-banner')), findsNothing, reason: 'nothing to offer yet');

    platform.offer();
    await tester.pumpAndSettle();
    expect(find.text('Install KaamNow'), findsOneWidget);

    await tester.tap(find.byKey(const Key('install-now')));
    await tester.pumpAndSettle();
    expect(platform.prompts, 1);
    expect(find.text('KaamNow is installed. You can open it from your home screen.'), findsOneWidget);
    expect(find.byKey(const Key('install-banner')), findsNothing);
  });

  testWidgets('"Not now" hides the banner and remembers it', (tester) async {
    final install = InstallController(platform: FakeInstallPlatform(canPrompt: true));
    await pumpCustomer(tester, install);
    await tester.tap(find.byKey(const Key('install-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('install-banner')), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool('kaamnow.installBannerDismissed'), isTrue);
    expect(install.offerInstall, isTrue, reason: 'still available from the account screen');
  });

  testWidgets('iPhone users get the Add to Home Screen steps instead of a prompt', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = FakeInstallPlatform(isIos: true);
    await pumpCustomer(tester, InstallController(platform: platform));
    expect(find.textContaining('Add to Home Screen'), findsOneWidget);
    expect(find.byKey(const Key('install-now')), findsNothing);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('install-tile')));
    await tester.pumpAndSettle();
    expect(find.text('How to install'), findsOneWidget);
    expect(platform.prompts, 0);
  });

  testWidgets('nothing is offered inside the installed app', (tester) async {
    await pumpCustomer(tester, InstallController(platform: FakeInstallPlatform(canPrompt: true, isStandalone: true)));
    expect(find.byKey(const Key('install-banner')), findsNothing);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('install-tile')), findsNothing);
  });
}
