import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session.dart';
import 'push_factory.dart' if (dart.library.js_interop) 'push_web.dart';
import 'push_platform.dart';

enum PushState {
  /// The server cannot deliver to this device, or the device has no push (e.g. Firebase not set up).
  unavailable,

  /// iPhone/iPad in Safari: install the app first.
  needsInstall,

  /// The person blocked notifications for this site in the browser.
  blocked,
  off,
  on,
}

/// Notifications for this device (browser or phone app): turning them on/off and keeping the server in step.
class PushController extends ChangeNotifier {
  PushController({PushPlatform? platform, this.bannerDismissed = false})
      : platform = platform ?? createPushPlatform();

  static const _dismissKey = 'kaamnow.pushBannerDismissed';

  final PushPlatform platform;
  bool bannerDismissed;
  Session? _session;
  bool _subscribed = false;
  bool busy = false;

  static Future<PushController> open() async {
    final prefs = await SharedPreferences.getInstance();
    return PushController(bannerDismissed: prefs.getBool(_dismissKey) ?? false);
  }

  String get _publicKey => _session?.config.webPushPublicKey ?? '';

  /// The server can deliver to this kind of device.
  bool get _serverReady {
    final config = _session?.config;
    if (config == null) return false;
    return platform.kind == PushKind.web ? config.webPushEnabled && _publicKey.isNotEmpty : config.phonePushEnabled;
  }

  /// Called with a screen (e.g. "/bookings/12") when the app is opened from a notification.
  void Function(String route)? openRoute;

  /// Called when a notification arrives while the app is open.
  void Function(ForegroundAlert alert)? showForeground;

  Future<void> _register(Map<String, dynamic> sub) => platform.kind == PushKind.web
      ? _session!.api.subscribeWebPush(sub)
      : _session!.api.registerDevice('${sub['token']}', '${sub['platform']}');

  Future<void> _unregister(String id) async {
    final api = _session?.api;
    if (api == null) return;
    platform.kind == PushKind.web ? await api.unsubscribeWebPush(id) : await api.unregisterDevice(id);
  }

  PushState get state {
    final session = _session;
    if (session == null || !_serverReady) return PushState.unavailable;
    if (platform.needsInstallFirst) return PushState.needsInstall;
    if (!platform.supported) return PushState.unavailable;
    if (platform.permission == 'denied') return PushState.blocked;
    return _subscribed && platform.permission == 'granted' ? PushState.on : PushState.off;
  }

  /// The "Turn on notifications" card on the home screens.
  bool get showBanner => state == PushState.off && !bannerDismissed;

  /// Connects to the session: re-registers this browser after sign-in (so its alerts go to
  /// whoever is signed in now) and removes it from the account before signing out.
  void attach(Session session) {
    if (identical(_session, session)) return;
    _session = session;
    session.beforeLogout.add(_onLogout);
    session.addListener(_onSession);
    platform.onResubscribe(() {
      if (platform.permission == 'granted' && _session?.user != null) enable();
    });
    platform.onOpen((route) {
      // Signed out: the router sends them to log in first.
      openRoute?.call(route);
    });
    platform.onForeground((alert) => showForeground?.call(alert));
    _onSession();
  }

  int? _syncedUser;

  Future<void> _onSession() async {
    final user = _session?.user;
    if (user == null || user.isAdmin) {
      _syncedUser = null;
      return;
    }
    if (_syncedUser == user.id) return;
    _syncedUser = user.id;
    try {
      final sub = await platform.current();
      if (sub != null && platform.permission == 'granted' && state != PushState.unavailable) {
        await _register(sub);
        _subscribed = true;
      } else {
        _subscribed = false;
      }
    } catch (_) {
      _subscribed = false;
    }
    notifyListeners();
  }

  /// Must be called from a tap: the browser only shows the permission question then.
  Future<bool> enable() async {
    if (state == PushState.unavailable || state == PushState.needsInstall) return false;
    busy = true;
    notifyListeners();
    try {
      final sub = await platform.subscribe(_publicKey);
      if (sub == null) return false;
      await _register(sub);
      _subscribed = true;
      return true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disable() async {
    busy = true;
    notifyListeners();
    try {
      // Tell the server first, while still signed in, then stop on the device.
      final sub = await platform.current();
      final id = sub == null ? null : '${sub['endpoint'] ?? sub['token'] ?? ''}';
      if (id != null && id.isNotEmpty) await _unregister(id);
      await platform.unsubscribe();
      _subscribed = false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> dismissBanner() async {
    bannerDismissed = true;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(_dismissKey, true);
    } catch (_) {}
  }

  /// Signed-out browsers get no alerts.
  Future<void> _onLogout() async {
    if (!_subscribed) return;
    try {
      await disable();
    } catch (_) {}
  }
}
