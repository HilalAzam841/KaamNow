import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's language (English or Urdu), remembered on this device.
///
/// English by default; Urdu once the user picks it in the language menu. Changing it updates the UI at once,
/// switches the layout to right-to-left for Urdu, and is sent to the server (see KaamNowApp)
/// so alerts and server messages come back in the same language.
class LocaleController extends ChangeNotifier {
  LocaleController({String? initial, this.store}) : _locale = Locale(supported.contains(initial) ? initial! : 'en');

  static const supported = ['en', 'ur'];
  static const _key = 'kaamnow.language';

  final LanguageStore? store;
  Locale _locale;

  Locale get locale => _locale;
  String get code => _locale.languageCode;
  bool get isUrdu => code == 'ur';

  /// The language the user picked on this device, else English. The browser's own language
  /// is ignored on purpose: the app always starts in English and Urdu is an explicit choice.
  static Future<LocaleController> open() async {
    final store = await PrefsLanguageStore.open();
    return LocaleController(initial: store.read() ?? 'en', store: store);
  }

  Future<void> set(String code) async {
    if (!supported.contains(code) || code == this.code) return;
    _locale = Locale(code);
    notifyListeners();
    await store?.write(code);
  }
}

abstract class LanguageStore {
  String? read();
  Future<void> write(String code);
}

class PrefsLanguageStore implements LanguageStore {
  PrefsLanguageStore._(this._prefs);
  static Future<PrefsLanguageStore> open() async => PrefsLanguageStore._(await SharedPreferences.getInstance());
  final SharedPreferences _prefs;
  @override
  String? read() => _prefs.getString(LocaleController._key);
  @override
  Future<void> write(String code) => _prefs.setString(LocaleController._key, code);
}
