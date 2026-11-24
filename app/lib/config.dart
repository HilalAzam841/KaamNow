/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run -d chrome --dart-define=API_BASE_URL=https://api.kaamnow.pk
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Map tiles. OpenStreetMap needs no key; swap for Google Maps once a key is available.
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
