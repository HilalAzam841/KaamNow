import 'package:flutter/foundation.dart';

import '../../config.dart';
import 'maps_loader_stub.dart' if (dart.library.js_interop) 'maps_loader_web.dart' as loader;

/// Which map the app shows. Google Maps once a key is set up, OpenStreetMap otherwise.
///
/// - Web: the browser key comes from the server (`maps.google_browser_key` in app config), so the
///   web app needs no rebuild when the key is added.
/// - Android and iPhone: the key is built into the app (GOOGLE_MAPS_API_KEY), because the native
///   map SDKs read it from the app's manifest / Info.plist.
class MapProvider {
  static bool useGoogle({required String browserKey, bool? web, TargetPlatform? platform, String? appKey}) {
    final isWeb = web ?? kIsWeb;
    if (isWeb) return browserKey.isNotEmpty;
    final p = platform ?? defaultTargetPlatform;
    if (p != TargetPlatform.android && p != TargetPlatform.iOS) return false;
    return (appKey ?? AppConfig.googleMapsKey).isNotEmpty;
  }

  /// On the web, loads Google's map script once. False if it could not load (the app then shows
  /// OpenStreetMap instead). On phones the SDK is part of the app, so this is immediate.
  static Future<bool> ready(String browserKey) => kIsWeb ? loader.loadGoogleMaps(browserKey) : Future.value(true);
}
