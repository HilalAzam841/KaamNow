import 'package:material_ui/material_ui.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

extension L10nContext on BuildContext {
  /// The app's strings in the current language: `context.t.logIn`.
  AppLocalizations get t => AppLocalizations.of(this);
}
