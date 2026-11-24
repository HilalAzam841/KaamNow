import 'package:shared_preferences/shared_preferences.dart';

/// Holds the JWT pair. On web this is backed by localStorage.
abstract class TokenStore {
  String? get access;
  String? get refresh;
  Future<void> save({required String access, String? refresh});
  Future<void> clear();
}

class PrefsTokenStore implements TokenStore {
  PrefsTokenStore._(this._prefs) : _access = _prefs.getString(_accessKey), _refresh = _prefs.getString(_refreshKey);

  static const _accessKey = 'kaamnow.access';
  static const _refreshKey = 'kaamnow.refresh';

  static Future<PrefsTokenStore> open() async => PrefsTokenStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  String? _access;
  String? _refresh;

  @override
  String? get access => _access;
  @override
  String? get refresh => _refresh;

  @override
  Future<void> save({required String access, String? refresh}) async {
    _access = access;
    await _prefs.setString(_accessKey, access);
    if (refresh != null) {
      _refresh = refresh;
      await _prefs.setString(_refreshKey, refresh);
    }
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }
}

/// In-memory store for tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({String? access, String? refresh}) : _access = access, _refresh = refresh; // ignore: prefer_initializing_formals
  String? _access;
  String? _refresh;
  @override
  String? get access => _access;
  @override
  String? get refresh => _refresh;
  @override
  Future<void> save({required String access, String? refresh}) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
