import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'install_factory.dart' if (dart.library.js_interop) 'install_web.dart';
import 'install_platform.dart';

/// "Install KaamNow" (add to home screen): whether to offer it, and doing it.
class InstallController extends ChangeNotifier {
  InstallController({InstallPlatform? platform, this.bannerDismissed = false})
      : platform = platform ?? createInstallPlatform() {
    this.platform.listen(notifyListeners);
  }

  static const _dismissKey = 'kaamnow.installBannerDismissed';

  final InstallPlatform platform;
  bool bannerDismissed;

  static Future<InstallController> open() async {
    final prefs = await SharedPreferences.getInstance();
    return InstallController(bannerDismissed: prefs.getBool(_dismissKey) ?? false);
  }

  /// The browser can install it with one tap.
  bool get canInstall => !platform.isStandalone && platform.canPrompt;

  /// iPhone/iPad: explain Share, then Add to Home Screen.
  bool get showIosSteps => !platform.isStandalone && platform.isIos;

  bool get offerInstall => canInstall || showIosSteps;

  /// The home-screen banner: offered until someone installs or dismisses it.
  bool get showBanner => offerInstall && !bannerDismissed;

  Future<bool> install() async {
    final accepted = await platform.prompt();
    notifyListeners();
    return accepted;
  }

  Future<void> dismissBanner() async {
    bannerDismissed = true;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(_dismissKey, true);
    } catch (_) {}
  }
}
