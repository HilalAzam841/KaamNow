import 'package:flutter/foundation.dart';

import '../api/kaamnow_api.dart';
import '../models/models.dart';
import 'api_exception.dart';
import 'token_store.dart';

enum SessionStatus { unknown, signedOut, signedIn }

/// Who is signed in. Drives routing.
class Session extends ChangeNotifier {
  Session(this.api, this.tokens) {
    api.client.onSessionExpired = _expired;
  }

  final KaamNowApi api;
  final TokenStore tokens;

  SessionStatus status = SessionStatus.unknown;
  User? user;
  ClientConfig config = ClientConfig.fallback();

  bool get isSignedIn => status == SessionStatus.signedIn && user != null;

  /// True after the user tapped "Log out" (as opposed to a session that expired).
  bool loggedOutByUser = false;

  /// Restores a saved session (if any) and loads public config.
  Future<void> restore() async {
    try {
      config = await api.appConfig();
    } catch (_) {
      // Keep defaults; the app still works without config.
    }
    if (tokens.access == null && tokens.refresh == null) {
      _set(SessionStatus.signedOut, null);
      return;
    }
    try {
      _set(SessionStatus.signedIn, await api.me());
    } on ApiException catch (e) {
      if (e.isUnauthorized) await tokens.clear();
      _set(SessionStatus.signedOut, null);
    }
  }

  Future<void> login(String phone, String password) async {
    final (u, access, refresh) = await api.login(phone.trim(), password);
    await tokens.save(access: access, refresh: refresh);
    _set(SessionStatus.signedIn, u);
  }

  Future<void> register({required String phone, required String password, required String fullName,
      required UserRole role, String? email, String? cnic}) async {
    final (u, access, refresh) = await api.register(
        phone: phone.trim(), password: password, fullName: fullName.trim(), role: role, email: email, cnic: cnic);
    await tokens.save(access: access, refresh: refresh);
    _set(SessionStatus.signedIn, u);
  }

  Future<void> refreshUser() async {
    user = await api.me();
    notifyListeners();
  }

  /// Run while still signed in, just before signing out (e.g. turning off this browser's alerts).
  final List<Future<void> Function()> beforeLogout = [];

  Future<void> logout() async {
    for (final hook in beforeLogout) {
      try {
        await hook();
      } catch (_) {}
    }
    final refresh = tokens.refresh;
    if (refresh != null) {
      try {
        await api.logout(refresh);
      } catch (_) {
        // Signing out locally is what matters.
      }
    }
    await tokens.clear();
    loggedOutByUser = true;
    _set(SessionStatus.signedOut, null);
  }

  void _expired() => _set(SessionStatus.signedOut, null);

  void _set(SessionStatus s, User? u) {
    if (s == SessionStatus.signedIn) loggedOutByUser = false;
    status = s;
    user = u;
    notifyListeners();
  }
}
