import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/core/install/install_controller.dart';
import 'package:kaamnow/core/push/push_controller.dart';
import 'package:kaamnow/ui/worker/job_feed_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'admin_test.dart' show paged;
import 'helpers.dart';
import 'portfolio_test.dart' show workerProfileJson;
import 'promos_test.dart' show pumpScreen;

void main() {
  group('worker job feed', () {
    late List<Object> jobs;

    Future<Harness> pumpFeed(WidgetTester tester) => pumpScreen(tester,
        MultiProvider(providers: [
          ChangeNotifierProvider(create: (_) => PushController(bannerDismissed: true)),
          ChangeNotifierProvider(create: (_) => InstallController(bannerDismissed: true)),
        ], child: const JobFeedScreen(refreshEvery: Duration(seconds: 20))), role: 'worker', setup: (h) {
      h.backend.on('GET /workers/me/', (_) => ok(workerProfileJson()));
      h.backend.on('GET /requests/', (_) => ok(paged(jobs)));
    });

    setUp(() => jobs = []);

    testWidgets('a new job shows up on its own, without reloading the page', (tester) async {
      final h = await pumpFeed(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job-11')), findsNothing);

      jobs = [requestJson()];
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job-11')), findsOneWidget);
      expect(h.backend.callsTo('GET /requests/').length, 2);
      expect(h.backend.callsTo('GET /requests/').last.url.queryParameters['scope'], 'feed');

      await tester.pumpWidget(const SizedBox()); // stops the timer
    });

    testWidgets('the refresh button reloads the list', (tester) async {
      await pumpFeed(tester);
      await tester.pumpAndSettle();
      jobs = [requestJson()];
      await tester.tap(find.byKey(const Key('feed-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job-11')), findsOneWidget);
      expect(find.text('Fan not working'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
