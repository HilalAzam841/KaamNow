/// How push notifications reach this device.
enum PushKind {
  /// Standard web push through the page's service worker (needs the server's VAPID key).
  web,

  /// Firebase Cloud Messaging in the Android and iPhone apps.
  firebase,
}

/// A notification that arrived while the app is open (the system does not show those).
class ForegroundAlert {
  ForegroundAlert(this.title, this.body, this.route);
  final String title;
  final String body;

  /// The screen it is about, e.g. "/bookings/12"; empty if none.
  final String route;
}

/// What this device can do about push notifications.
abstract class PushPlatform {
  PushKind get kind;

  /// Notifications can work on this device (browser features, or Firebase set up in the app).
  bool get supported;

  /// iPhone/iPad in Safari: web push only works in the installed app (Add to Home Screen), iOS 16.4+.
  bool get needsInstallFirst;

  /// 'default' (not asked yet), 'granted' or 'denied'.
  String get permission;

  /// This device's current registration, or null. Web: PushSubscription.toJSON().
  /// Firebase: {'token': ..., 'platform': 'android' | 'ios'}.
  Future<Map<String, dynamic>?> current();

  /// Asks for permission (on the web this must follow a tap) and registers. Null if refused.
  Future<Map<String, dynamic>?> subscribe(String publicKey);

  /// Stops notifications on this device; returns what the server knows it by (endpoint or token).
  Future<String?> unsubscribe();

  /// The registration changed (keys rotated, new token): register again.
  void onResubscribe(void Function() callback);

  /// The app was opened by tapping a notification. [route] is e.g. "/bookings/12/chat".
  void onOpen(void Function(String route) callback);

  /// A notification arrived while the app was open.
  void onForeground(void Function(ForegroundAlert alert) callback);
}

/// Tests, and builds where Firebase is not set up.
class NoPushPlatform implements PushPlatform {
  const NoPushPlatform();
  @override
  PushKind get kind => PushKind.web;
  @override
  bool get supported => false;
  @override
  bool get needsInstallFirst => false;
  @override
  String get permission => 'default';
  @override
  Future<Map<String, dynamic>?> current() async => null;
  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async => null;
  @override
  Future<String?> unsubscribe() async => null;
  @override
  void onResubscribe(void Function() callback) {}
  @override
  void onOpen(void Function(String route) callback) {}
  @override
  void onForeground(void Function(ForegroundAlert alert) callback) {}
}
