import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/locale_controller.dart';

/// The language menu in the top bar: shows the current language and lets the user pick
/// English or Urdu. English is the default; Urdu is only used once someone chooses it.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  static const _names = {'en': 'English', 'ur': 'اردو'};

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    return PopupMenuButton<String>(
      key: const Key('language-menu'),
      tooltip: 'Language / زبان',
      initialValue: locale.code,
      onSelected: locale.set,
      itemBuilder: (_) => [
        for (final code in LocaleController.supported)
          CheckedPopupMenuItem(
            key: Key('language-$code'),
            value: code,
            checked: code == locale.code,
            child: Text(_names[code]!),
          ),
      ],
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language, size: 20),
          const SizedBox(width: 6),
          Text(_names[locale.code]!),
          const Icon(Icons.arrow_drop_down, size: 20),
        ]),
      ),
    );
  }
}
