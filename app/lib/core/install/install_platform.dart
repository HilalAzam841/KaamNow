/// What the browser can do about installing KaamNow on the home screen.
abstract class InstallPlatform {
  /// The browser offered an install prompt (Chrome, Edge, Samsung Internet on Android/desktop).
  bool get canPrompt;

  /// Already running as the installed app.
  bool get isStandalone;

  /// iPhone/iPad Safari: no prompt exists; people use Share, then "Add to Home Screen".
  bool get isIos;

  /// Shows the browser's install dialog. True when the person accepted.
  Future<bool> prompt();

  /// Calls [onChange] when the browser offers the prompt or the app gets installed.
  void listen(void Function() onChange);
}

/// Not running in a browser (tests, and the future Android/iOS builds): nothing to install.
class NoInstallPlatform implements InstallPlatform {
  const NoInstallPlatform();
  @override
  bool get canPrompt => false;
  @override
  bool get isStandalone => false;
  @override
  bool get isIos => false;
  @override
  Future<bool> prompt() async => false;
  @override
  void listen(void Function() onChange) {}
}
