import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_platform.dart';

/// The Firebase project, passed in when the app is built (see app/README.md, "Push on phones"):
///   --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_API_KEY=...
///   --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_ANDROID_APP_ID=...
///   --dart-define=FIREBASE_IOS_APP_ID=...
/// Without them the app simply has no push (alerts still show inside the app).
class FirebaseConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static String get appId => defaultTargetPlatform == TargetPlatform.iOS ? iosAppId : androidAppId;

  static bool get isSet => projectId.isNotEmpty && apiKey.isNotEmpty && senderId.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: 'pk.kaamnow.app',
      );
}

/// Firebase Cloud Messaging for the Android and iPhone apps. Nothing touches Firebase until the
/// first call that needs it, so builds and tests without a Firebase project are unaffected.
class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform({bool? configured}) : _configured = configured ?? FirebaseConfig.isSet;

  final bool _configured;
  Future<FirebaseMessaging>? _ready;
  String _permission = 'default';
  final _resubscribe = <void Function()>[];
  final _open = <void Function(String)>[];
  final _foreground = <void Function(ForegroundAlert)>[];
  String? _lastToken;
  Completer<String>? _tokenWaiter;

  @override
  PushKind get kind => PushKind.firebase;

  bool get _phone =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get supported => _configured && _phone;

  @override
  bool get needsInstallFirst => false;

  @override
  String get permission => _permission;

  String get _platformName => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static String routeOf(RemoteMessage m) {
    final route = m.data['route'];
    return route is String && route.startsWith('/') && !route.startsWith('//') ? route : '';
  }

  Future<FirebaseMessaging> _messaging() => _ready ??= () async {
        if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: FirebaseConfig.options);
        final m = FirebaseMessaging.instance;
        m.onRegistered.listen((token) {
          final changed = _lastToken != null && _lastToken != token;
          _lastToken = token;
          final waiter = _tokenWaiter;
          if (waiter != null && !waiter.isCompleted) waiter.complete(token);
          if (changed) {
            for (final cb in _resubscribe) {
              cb();
            }
          }
        });
        m.onUnregistered.listen((_) => _lastToken = null);
        FirebaseMessaging.onMessageOpenedApp.listen(_opened);
        FirebaseMessaging.onMessage.listen((msg) {
          final n = msg.notification;
          if (n == null) return;
          final alert = ForegroundAlert(n.title ?? '', n.body ?? '', routeOf(msg));
          for (final cb in _foreground) {
            cb(alert);
          }
        });
        // Opened from a notification while the app was not running at all.
        final initial = await m.getInitialMessage();
        if (initial != null) Future.microtask(() => _opened(initial));
        return m;
      }();

  void _opened(RemoteMessage msg) {
    final route = routeOf(msg);
    if (route.isEmpty) return;
    for (final cb in _open) {
      cb(route);
    }
  }

  static String _status(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => 'granted',
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => 'denied',
        AuthorizationStatus.notDetermined => 'default',
      };

  Future<Map<String, dynamic>?> _token(FirebaseMessaging m) async {
    if (defaultTargetPlatform == TargetPlatform.iOS && await m.getAPNSToken() == null) {
      return null; // Apple has not given this device a push address (e.g. a simulator)
    }
    var token = _lastToken;
    if (token == null) {
      final waiter = _tokenWaiter = Completer<String>();
      await m.register();
      token = _lastToken ?? await waiter.future.timeout(const Duration(seconds: 30));
    }
    return {'token': token, 'platform': _platformName};
  }

  @override
  Future<Map<String, dynamic>?> current() async {
    if (!supported) return null;
    final m = await _messaging();
    _permission = _status((await m.getNotificationSettings()).authorizationStatus);
    return _permission == 'granted' ? _token(m) : null;
  }

  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async {
    if (!supported) return null;
    final m = await _messaging();
    _permission = _status((await m.requestPermission()).authorizationStatus);
    return _permission == 'granted' ? _token(m) : null;
  }

  @override
  Future<String?> unsubscribe() async {
    if (!supported) return null;
    final m = await _messaging();
    final token = _lastToken;
    await m.unregister();
    _lastToken = null;
    return token;
  }

  @override
  void onResubscribe(void Function() callback) => _resubscribe.add(callback);

  @override
  void onOpen(void Function(String route) callback) {
    _open.add(callback);
    if (supported) _messaging().ignore(); // so a tap that launched the app is delivered
  }

  @override
  void onForeground(void Function(ForegroundAlert alert) callback) => _foreground.add(callback);
}
