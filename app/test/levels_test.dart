import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/customer/worker_public_screen.dart';
import 'package:kaamnow/ui/worker/level_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show paged;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> progressJson({String level = 'rising', String? next = 'trusted', bool verified = true,
        List<String> badges = const ['verified', 'experienced']}) =>
    {
      'level': level,
      'badges': badges,
      'next_level': next,
      'requirements': next == null
          ? []
          : [
              {'key': 'jobs', 'target': '15.0', 'value': '9.00', 'met': false},
              {'key': 'rating', 'target': '4.3', 'value': '4.50', 'met': true},
              {'key': 'reviews', 'target': '5.0', 'value': '3.00', 'met': false},
              {'key': 'no_shows', 'target': '1.0', 'value': '0.00', 'met': true},
              {'key': 'cancel_rate', 'target': '10.0', 'value': '0.00', 'met': true},
            ],
      'verified': verified,
      'window_days': 90,
      'stats': {'jobs': 9, 'rating': '4.50', 'reviews': 3, 'no_shows': 0, 'cancel_rate': '0.0'},
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('level fields parse', () {
    final w = PublicWorker.fromJson({...workerJson(), 'level': 'top_rated', 'badges': ['verified', 'jobs_100']});
    expect(w.level, 'top_rated');
    expect(w.badges, ['verified', 'jobs_100']);
    expect(PublicWorker.fromJson(workerJson()).level, 'new');
    final p = LevelProgress.fromJson(progressJson());
    expect(p.requirements.first.progress, closeTo(0.6, 1e-9));
    expect(p.requirements[1].progress, 1);
  });

  testWidgets('a worker sees their level, what the next one needs, and their badges', (tester) async {
    tall(tester);
    await pumpScreen(tester, const LevelScreen(), role: 'worker',
        setup: (h) => h.backend.on('GET /workers/me/level/', (_) => ok(progressJson())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level-rising')), findsOneWidget);
    expect(find.text('To become Trusted'), findsOneWidget);
    expect(find.text('Jobs done: 9 of 15'), findsOneWidget);
    expect(find.text('Average rating: 4.5 (needs 4.3)'), findsOneWidget);
    expect(find.text('Reviews: 3 of 5'), findsOneWidget);
    expect(find.text('Confirmed no-shows in 90 days: 0 (at most 1)'), findsOneWidget);
    expect(find.text('Bookings you cancelled in 90 days: 0% (at most 10%)'), findsOneWidget);
    expect(find.byKey(const Key('badge-verified')), findsOneWidget);
    expect(find.byKey(const Key('badge-experienced')), findsOneWidget);
  });

  testWidgets('top rated and unverified workers', (tester) async {
    tall(tester);
    await pumpScreen(tester, const LevelScreen(), role: 'worker',
        setup: (h) => h.backend.on('GET /workers/me/level/', (_) => ok(progressJson(level: 'top_rated', next: null))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('top-level')), findsOneWidget);
    expect(find.byKey(const Key('req-jobs')), findsNothing);
  });

  testWidgets('an unverified worker is told levels start after verification', (tester) async {
    tall(tester);
    await pumpScreen(tester, const LevelScreen(), role: 'worker',
        setup: (h) => h.backend.on('GET /workers/me/level/',
            (_) => ok(progressJson(level: 'new', next: 'rising', verified: false, badges: []))));
    await tester.pumpAndSettle();
    expect(find.text('Levels start once your account is verified.'), findsOneWidget);
    expect(find.byKey(const Key('req-jobs')), findsNothing);
    expect(find.textContaining('No badges yet'), findsOneWidget);
  });

  testWidgets('customers see the level and badges on a worker profile', (tester) async {
    tall(tester);
    await pumpScreen(tester, const WorkerPublicScreen(id: 7), setup: (h) {
      h.backend.on('GET /workers/7/', (_) => ok({
            ...workerJson(),
            'level': 'trusted',
            'badges': ['verified', 'customer_favourite', 'always_on_time'],
          }));
      h.backend.on('GET /workers/7/reviews/', (_) => ok(paged([])));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level-trusted')), findsOneWidget);
    expect(find.text('Trusted'), findsOneWidget);
    expect(find.byKey(const Key('badge-customer_favourite')), findsOneWidget);
    expect(find.byKey(const Key('badge-always_on_time')), findsOneWidget);
    expect(find.byKey(const Key('badge-verified')), findsNothing, reason: 'the tick already shows it');
  });
}
