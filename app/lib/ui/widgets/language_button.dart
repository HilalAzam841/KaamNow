import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/locale_controller.dart';

/// Switches between English and Urdu. Shows the language you would switch *to*,
/// written in that language, so it is readable whichever language is active.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    return TextButton.icon(
      key: const Key('language-toggle'),
      onPressed: () => locale.set(locale.isUrdu ? 'en' : 'ur'),
      icon: const Icon(Icons.translate),
      label: Text(locale.isUrdu ? 'English' : 'اردو'),
    );
  }
}
