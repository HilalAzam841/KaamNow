import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'api/kaamnow_api.dart';
import 'app.dart';
import 'config.dart';
import 'core/api_client.dart';
import 'core/install/install_controller.dart';
import 'core/locale_controller.dart';
import 'core/push/push_controller.dart';
import 'core/session.dart';
import 'core/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the browser URL in step with pushed screens, so reload and shared links reopen them.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  await initializeDateFormatting();
  final locale = await LocaleController.open();
  final install = await InstallController.open();
  final push = await PushController.open();
  final tokens = await PrefsTokenStore.open();
  final api = KaamNowApi(ApiClient(root: AppConfig.apiRoot, tokens: tokens));
  final session = Session(api, tokens);
  runApp(KaamNowApp(session: session, locale: locale, install: install, push: push));
  await session.restore();
}
