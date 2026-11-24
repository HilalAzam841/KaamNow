/// What this browser can do about push notifications.
abstract class PushPlatform {
  /// Service worker, Push API and notifications are all available.
  bool get supported;

  /// iPhone/iPad: web push only works in the installed app (Add to Home Screen), iOS 16.4+.
  bool get needsInstallFirst;

  /// 'default' (not asked yet), 'granted' or 'denied'.
  String get permission;

  /// The current subscription as PushSubscription.toJSON(), or null.
  Future<Map<String, dynamic>?> current();

  /// Asks for permission (must follow a tap) and subscribes. Null if refused.
  Future<Map<String, dynamic>?> subscribe(String publicKey);

  /// Unsubscribes this browser; returns the endpoint it had, if any.
  Future<String?> unsubscribe();

  /// The service worker asks the app to subscribe again (the browser rotated the keys).
  void onResubscribe(void Function() callback);
}

/// Tests and the future native builds (which will use Firebase instead).
class NoPushPlatform implements PushPlatform {
  const NoPushPlatform();
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
}
