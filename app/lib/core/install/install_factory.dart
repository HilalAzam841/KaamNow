import 'install_platform.dart';

/// Outside the browser there is nothing to install. On the web, install_web.dart is used instead.
InstallPlatform createInstallPlatform() => const NoInstallPlatform();
