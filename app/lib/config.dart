/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run -d chrome --dart-define=API_BASE_URL=https://api.kaamnow.pk
class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

  /// An empty API_BASE_URL means "the server this page came from": the production web image is
  /// built that way so one image works on any domain (the proxy sends /api and /ws to Django).
  static String get apiBaseUrl => _apiBaseUrl.isEmpty ? Uri.base.origin : _apiBaseUrl;
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Google Maps key for the Android and iPhone apps (also set it for the native build, see
  /// app/README.md). Empty: the apps show OpenStreetMap.
  static const googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// OpenStreetMap tiles, used when Google Maps is not set up.
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static String get apiRoot => '$apiBaseUrl/api/v1';

  static String get wsBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws').toString();
  }
}
