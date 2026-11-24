import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/core/session.dart';
import 'package:kaamnow/ui/customer/request_detail_screen.dart';
import 'package:kaamnow/ui/worker/job_detail_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// Hosts one screen with a router so pushes / replacements can be asserted.
Widget host(Session session, String initial, Map<String, Widget Function(GoRouterState)> routes) {
  final router = GoRouter(initialLocation: initial, routes: [
    for (final e in routes.entries) GoRoute(path: e.key, builder: (_, s) => e.value(s)),
  ]);
  return ChangeNotifierProvider.value(value: session, child: MaterialApp.router(routerConfig: router));
}

void main() {
  group('login', () {
    testWidgets('shows the server error, then signs in and opens customer home', (tester) async {
      final h = Harness();
      h.backend.on('GET /app/config/', (_) => ok(configJson()));
      h.backend.on('POST /auth/login/', (req) {
        final body = jsonDecode(req.body) as Map;
        if (body['password'] != 'correct-horse') {
          return err(401, 'authentication_failed', 'Invalid phone number or password.');
        }
        return ok({'user': userJson(), 'tokens': {'access': 'A', 'refresh': 'R'}});
      });
      h.backend.on('GET /services/categories/', (_) => ok([
            {'id': 1, 'name': 'Electrician', 'slug': 'electrician', 'description': '', 'icon': '', 'is_active': true, 'sort_order': 1},
            {'id': 2, 'name': 'Plumber', 'slug': 'plumber', 'description': '', 'icon': '', 'is_active': true, 'sort_order': 2},
          ]));
      h.backend.on('GET /notifications/unread-count/', (_) => ok({'unread': 3}));

      await tester.pumpWidget(KaamNowApp(session: h.session));
      await h.session.restore();
      await tester.pumpAndSettle();
      expect(find.text('Log in'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login-phone')), '03001234567');
      await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Invalid phone number or password.'), findsOneWidget);
      expect(h.tokens.access, isNull);

      await tester.enterText(find.byKey(const Key('login-password')), 'correct-horse');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(h.tokens.access, 'A');
      expect(find.text('Salam, Ayesha'), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('Plumber'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'unread badge');
    });

    testWidgets('worker sign-up asks for CNIC and shows field errors from the server', (tester) async {
      final h = Harness();
      h.backend.on('GET /app/config/', (_) => ok(configJson()));
      h.backend.on('POST /auth/register/', (req) {
        final body = jsonDecode(req.body) as Map;
        expect(body['role'], 'worker');
        expect(body['cnic_number'], '35202-1234567-1');
        return err(400, 'validation_error', 'Invalid input.', {'phone': ['An account with this phone number already exists.']});
      });
      await tester.pumpWidget(KaamNowApp(session: h.session));
      await h.session.restore();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reg-cnic')), findsNothing);
      await tester.tap(find.text('Offer services'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('reg-name')), 'Bilal Ahmed');
      await tester.enterText(find.byKey(const Key('reg-phone')), '03001234567');
      await tester.enterText(find.byKey(const Key('reg-cnic')), '35202-1234567-1');
      await tester.enterText(find.byKey(const Key('reg-password')), 'longpassword');
      await tester.ensureVisible(find.byKey(const Key('reg-submit')));
      await tester.tap(find.byKey(const Key('reg-submit')));
      await tester.pumpAndSettle();
      expect(find.text('An account with this phone number already exists.'), findsOneWidget);
    });
  });

  group('customer compares offers', () {
    Future<Harness> setup(WidgetTester tester, Map<String, dynamic> offer) async {
      final h = Harness(access: 'A', refresh: 'R');
      h.backend.on('GET /requests/11/', (_) => ok(requestJson()));
      h.backend.on('GET /requests/11/offers/', (_) => ok({'count': 1, 'next': null, 'previous': null, 'results': [offer]}));
      await tester.pumpWidget(host(h.session, '/requests/11', {
        '/requests/:id': (s) => RequestDetailScreen(id: int.parse(s.pathParameters['id']!)),
        '/bookings/:id': (s) => Scaffold(body: Text('booking ${s.pathParameters['id']}')),
      }));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('accepting an offer books the worker and opens the booking', (tester) async {
      final h = await setup(tester, offerJson());
      h.backend.on('POST /offers/3/accept/', (_) => ok(bookingJson(), status: 201));
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.text('Rs 1,500'), findsWidgets);
      await tester.tap(find.byKey(const Key('accept-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Book'));
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('POST /offers/3/accept/'), hasLength(1));
      expect(find.text('booking 21'), findsOneWidget);
    });

    testWidgets('sending a counter offer posts the amount', (tester) async {
      final h = await setup(tester, offerJson(price: '1800.00'));
      h.backend.on('POST /offers/3/negotiate/', (req) {
        expect(jsonDecode(req.body), {'action': 'counter', 'amount': '1600', 'message': ''});
        return ok({'offer': offerJson(price: '1600.00', awaiting: 'worker'), 'booking': null});
      });
      await tester.tap(find.byKey(const Key('counter-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('counter-amount')), '1600');
      await tester.tap(find.byKey(const Key('counter-send')));
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('POST /offers/3/negotiate/'), hasLength(1));
    });

    testWidgets('while the worker is deciding, the customer cannot accept or counter', (tester) async {
      await setup(tester, offerJson(awaiting: 'worker'));
      expect(find.byKey(const Key('accept-3')), findsNothing);
      expect(find.byKey(const Key('counter-3')), findsNothing);
      expect(find.textContaining('Waiting for Bilal'), findsOneWidget);
    });
  });

  group('worker', () {
    testWidgets('sends an offer on an open job', (tester) async {
      final h = Harness(access: 'A', refresh: 'R');
      h.backend.on('GET /requests/11/', (_) => ok(requestJson()));
      h.backend.on('GET /requests/11/offers/', (_) => ok({'count': 0, 'next': null, 'previous': null, 'results': []}));
      h.backend.on('POST /requests/11/offers/', (req) {
        final body = jsonDecode(req.body) as Map;
        expect(body['price'], '1700');
        expect(body['estimated_arrival_minutes'], 20);
        return ok(offerJson(price: '1700.00'), status: 201);
      });
      await tester.pumpWidget(host(h.session, '/jobs/11', {
        '/jobs/:id': (s) => JobDetailScreen(id: int.parse(s.pathParameters['id']!)),
      }));
      await tester.pumpAndSettle();
      expect(find.text('The exact address is shared once you are booked.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('offer-price')), '50');
      await tester.enterText(find.byKey(const Key('offer-eta')), '20');
      await tester.ensureVisible(find.byKey(const Key('offer-submit')));
      await tester.tap(find.byKey(const Key('offer-submit')));
      await tester.pump();
      expect(find.text('Minimum is Rs 100'), findsOneWidget);
      expect(h.backend.callsTo('POST /requests/11/offers/'), isEmpty);

      await tester.enterText(find.byKey(const Key('offer-price')), '1700');
      await tester.tap(find.byKey(const Key('offer-submit')));
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('POST /requests/11/offers/'), hasLength(1));
      expect(find.text('Your offer'), findsOneWidget);
    });
  });
}
