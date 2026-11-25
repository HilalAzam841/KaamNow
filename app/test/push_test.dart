import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/core/push/push_controller.dart';
import 'package:kaamnow/core/push/push_platform.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

const endpoint = 'https://fcm.googleapis.com/fcm/send/test-endpoint';
Map<String, dynamic> subscriptionJson() => {
      'endpoint': endpoint,
      'expirationTime': null,
      'keys': {'p256dh': 'BKey', 'auth': 'auth'},
    };

class FakePushPlatform implements PushPlatform {
  FakePushPlatform(
      {this.permission = 'default', this.allow = true, this.needsInstallFirst = false, this.existing, this.kind = PushKind.web});
  @override
  final PushKind kind;
  void Function(String route)? opened;
  void Function(ForegroundAlert alert)? foreground;
  @override
  void onOpen(void Function(String route) callback) => opened = callback;
  @override
  void onForeground(void Function(ForegroundAlert alert) callback) => foreground = callback;
  @override
  String permission;
  final bool allow;
  @override
  final bool needsInstallFirst;
  Map<String, dynamic>? existing;
  String? subscribedWithKey;

  @override
  bool get supported => true;
  @override
  Future<Map<String, dynamic>?> current() async => existing;
  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async {
    permission = allow ? 'granted' : 'denied';
    if (!allow) return null;
    subscribedWithKey = publicKey;
    return existing = kind == PushKind.web ? subscriptionJson() : {'token': 'fcm-token-1', 'platform': 'android'};
  }

  @override
  Future<String?> unsubscribe() async {
    final had = (existing?['endpoint'] ?? existing?['token']) as String?;
    existing = null;
    return had;
  }

  @override
  void onResubscribe(void Function() callback) {}
}

Map<String, dynamic> pushConfig({bool enabled = true, bool phone = false}) => {
      ...configJson(),
      'push_enabled': phone,
      'web_push': {'enabled': enabled, 'public_key': enabled ? 'BPublicKey' : ''},
    };

Future<Harness> pumpSignedIn(WidgetTester tester, PushController push,
    {bool enabled = true, bool phone = false, String role = 'customer'}) async {
  final h = Harness(access: 'A', refresh: 'R');
  h.backend.on('GET /app/config/', (_) => ok(pushConfig(enabled: enabled, phone: phone)));
  h.backend.on('GET /auth/me/', (_) => ok(userJson(role: role)));
  h.backend.on('GET /services/categories/', (_) => ok([]));
  h.backend.on('GET /notifications/unread-count/', (_) => ok({'unread': 0}));
  h.backend.on('POST /notifications/web-push/subscribe/', (_) => ok({'subscribed': true}, status: 201));
  h.backend.on('POST /notifications/web-push/unsubscribe/', (_) => ok({'unsubscribed': true}));
  h.backend.on('POST /notifications/devices/', (_) => ok({'token': 'fcm-token-1'}, status: 201));
  h.backend.on('DELETE /notifications/devices/', (_) => ok({'deleted': 1}));
  h.backend.on('POST /auth/logout/', (_) => ok(null));
  await tester.pumpWidget(KaamNowApp(session: h.session, push: push));
  await h.session.restore();
  await tester.pumpAndSettle();
  return h;
}

Future<void> openAccount(WidgetTester tester) async {
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('turning on from the home card asks the browser and registers this device', (tester) async {
    final platform = FakePushPlatform();
    final h = await pumpSignedIn(tester, PushController(platform: platform));
    expect(find.text('Get alerts on this device'), findsOneWidget);

    await tester.tap(find.byKey(const Key('push-enable')));
    await tester.pumpAndSettle();
    expect(platform.subscribedWithKey, 'BPublicKey');
    final call = h.backend.callsTo('POST /notifications/web-push/subscribe/').single;
    expect(jsonDecode(call.body)['endpoint'], endpoint);
    expect(find.text('Notifications are on for this device.'), findsOneWidget);
    expect(find.byKey(const Key('push-banner')), findsNothing);

    await openAccount(tester);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('push-switch'))).value, isTrue);
  });

  testWidgets('refusing permission leaves it off and says so', (tester) async {
    final h = await pumpSignedIn(tester, PushController(platform: FakePushPlatform(allow: false)));
    await tester.tap(find.byKey(const Key('push-enable')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications were not allowed.'), findsOneWidget);
    expect(h.backend.callsTo('POST /notifications/web-push/subscribe/'), isEmpty);
    await openAccount(tester);
    expect(find.textContaining('Blocked in your browser'), findsOneWidget);
  });

  testWidgets('the account switch turns them off and tells the server', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = FakePushPlatform(permission: 'granted', existing: subscriptionJson());
    final h = await pumpSignedIn(tester, PushController(platform: platform));
    expect(h.backend.callsTo('POST /notifications/web-push/subscribe/'), hasLength(1),
        reason: 'an existing subscription is linked to whoever signed in');
    await openAccount(tester);
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /notifications/web-push/unsubscribe/').single.body), {'endpoint': endpoint});
    expect(platform.existing, isNull);
  });

  testWidgets('signing out removes this device from the account first', (tester) async {
    final platform = FakePushPlatform(permission: 'granted', existing: subscriptionJson());
    final h = await pumpSignedIn(tester, PushController(platform: platform));
    await h.session.logout();
    await tester.pumpAndSettle();
    final unsubscribe = h.backend.callsTo('POST /notifications/web-push/unsubscribe/').single;
    expect(unsubscribe.headers['Authorization'], 'Bearer A', reason: 'sent while still signed in');
    expect(platform.existing, isNull);
  });

  testWidgets('iPhone in Safari is told to install the app first', (tester) async {
    await pumpSignedIn(tester, PushController(platform: FakePushPlatform(needsInstallFirst: true)));
    expect(find.byKey(const Key('push-banner')), findsNothing);
    await openAccount(tester);
    expect(find.textContaining('first install KaamNow'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('push-switch'))).onChanged, isNull);
  });

  testWidgets('nothing is shown when the server has no push keys', (tester) async {
    await pumpSignedIn(tester, PushController(platform: FakePushPlatform()), enabled: false);
    expect(find.byKey(const Key('push-banner')), findsNothing);
    await openAccount(tester);
    expect(find.byKey(const Key('push-switch')), findsNothing);
  });

  group('Android and iPhone app', () {
    FakePushPlatform phone({String permission = 'default', Map<String, dynamic>? existing}) =>
        FakePushPlatform(kind: PushKind.firebase, permission: permission, existing: existing);

    testWidgets('turning on registers the phone with the server', (tester) async {
      final platform = phone();
      final h = await pumpSignedIn(tester, PushController(platform: platform), enabled: false, phone: true);
      await tester.tap(find.byKey(const Key('push-enable')));
      await tester.pumpAndSettle();
      final call = h.backend.callsTo('POST /notifications/devices/').single;
      expect(jsonDecode(call.body), {'token': 'fcm-token-1', 'platform': 'android'});
      expect(h.backend.callsTo('POST /notifications/web-push/subscribe/'), isEmpty);
      expect(find.text('Notifications are on for this device.'), findsOneWidget);
    });

    testWidgets('signing out removes the phone from the account first', (tester) async {
      final platform = phone(permission: 'granted', existing: {'token': 'fcm-token-1', 'platform': 'android'});
      final h = await pumpSignedIn(tester, PushController(platform: platform), enabled: false, phone: true);
      expect(h.backend.callsTo('POST /notifications/devices/'), hasLength(1));
      await h.session.logout();
      await tester.pumpAndSettle();
      final call = h.backend.callsTo('DELETE /notifications/devices/').single;
      expect(jsonDecode(call.body), {'token': 'fcm-token-1'});
      expect(call.headers['Authorization'], 'Bearer A');
      expect(platform.existing, isNull);
    });

    testWidgets('nothing is shown until Firebase is set up on the server', (tester) async {
      await pumpSignedIn(tester, PushController(platform: phone()), phone: false);
      expect(find.byKey(const Key('push-banner')), findsNothing);
      await openAccount(tester);
      expect(find.byKey(const Key('push-switch')), findsNothing);
    });

    testWidgets('a blocked phone points to the phone settings', (tester) async {
      await pumpSignedIn(tester, PushController(platform: phone(permission: 'denied')), enabled: false, phone: true);
      await openAccount(tester);
      expect(find.textContaining('Blocked in your phone settings'), findsOneWidget);
      expect(find.textContaining('Blocked in your browser'), findsNothing);
    });

    testWidgets('tapping a notification opens its screen', (tester) async {
      final platform = phone(permission: 'granted', existing: {'token': 'fcm-token-1', 'platform': 'android'});
      await pumpSignedIn(tester, PushController(platform: platform), enabled: false, phone: true);
      expect(platform.opened, isNotNull);
      platform.opened!('/account');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('push-switch')), findsOneWidget);
    });

    testWidgets('a notification while the app is open shows a bar with Open', (tester) async {
      final platform = phone(permission: 'granted', existing: {'token': 'fcm-token-1', 'platform': 'android'});
      await pumpSignedIn(tester, PushController(platform: platform), enabled: false, phone: true);
      platform.foreground!(ForegroundAlert('New offer', 'Rs 1500 from Ali', '/account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('push-foreground')), findsOneWidget);
      expect(find.textContaining('New offer'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('push-switch')), findsOneWidget);
    });
  });
}
