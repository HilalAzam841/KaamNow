import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/api/admin_api.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/ui/admin/overview_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Map<String, dynamic> paged(List<Object> results) =>
    {'count': results.length, 'page': 1, 'total_pages': 1, 'next': null, 'previous': null, 'results': results};

Map<String, dynamic> adminWorkerJson({List<String> docs = const ['cnic_front', 'cnic_back']}) => {
      'id': 5,
      'full_name': 'Bilal Ahmed',
      'phone': '+923210599243',
      'cnic_number': '3520205992431',
      'bio': 'Electrician for 6 years',
      'experience_years': 6,
      'profile_picture': null,
      'service_area': 'Gulberg',
      'service_radius_km': '10.00',
      'is_available': false,
      'verification_status': 'pending',
      'rejection_reason': '',
      'average_rating': '0.00',
      'rating_count': 0,
      'completed_jobs_count': 0,
      'services': [
        {'id': 1, 'category': 1, 'category_name': 'Electrician', 'description': '', 'starting_price': '500.00', 'is_active': true}
      ],
      'documents_uploaded': docs,
      'created_at': '2026-11-24T13:56:48+05:00',
      'email': null,
      'documents': [
        for (final (i, d) in docs.indexed)
          {'id': i + 1, 'document_type': d, 'original_filename': '$d.jpg', 'status': 'pending', 'created_at': '2026-11-24T13:56:56+05:00'}
      ],
    };

Map<String, dynamic> adminUserJson({int id = 14, bool suspended = false}) => {
      'id': id,
      'phone': '+923211797832',
      'email': null,
      'full_name': 'Sana Malik',
      'role': 'customer',
      'is_active': true,
      'is_suspended': suspended,
      'suspended_reason': suspended ? 'Fake jobs' : '',
      'date_joined': '2026-11-24T14:16:46+05:00',
      'last_login': null,
    };

/// Signs in as an admin with an overview screen that has data to show.
Future<Harness> adminHarness() async {
  final h = Harness(access: 'A', refresh: 'R');
  h.backend.on('GET /app/config/', (_) => ok(configJson()));
  h.backend.on('GET /auth/me/', (_) => ok(userJson(role: 'admin', name: 'Admin')));
  h.backend.on('GET /admin/dashboard/', (_) => ok({
        'users': {'admin': 1, 'customer': 9, 'worker': 4},
        'suspended_users': 0,
        'workers': {'pending': 1, 'verified': 3, 'online': 2},
        'requests': {'open': 2},
        'bookings': {'completed': 4},
        'bookings_today': 1,
        'gross_booking_value': '7200.00',
        'total_commission': '720.00',
        'commission_rate_percent': '10.00',
      }));
  h.backend.on('GET /admin/reports/', (_) => ok({
        'requests_by_status': {'open': 2},
        'bookings_by_status': {'completed': 4},
        'request_to_booking_conversion': 0.667,
        'bookings_by_category': [
          {'category': 'Electrician', 'bookings': 4, 'completed': 4, 'avg_price': '1800.00'}
        ],
        'top_workers': [
          {'id': 5, 'name': 'Bilal Ahmed', 'completed_jobs': 4, 'average_rating': '4.75'}
        ],
        'daily_bookings_last_30_days': [
          {'date': '2026-11-24', 'bookings': 4}
        ],
      }));
  h.backend.on('GET /admin/revenue/other/', (_) => ok({
        'subscription_revenue': '0.00',
        'featured_revenue': '0.00',
        'emergency_fee_revenue': '300.00',
        'active_subscriptions': {},
        'active_featured_listings': 0,
        'open_complaints': 2,
      }));
  await h.session.restore();
  return h;
}

Future<void> pumpAdmin(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(KaamNowApp(session: h.session));
  await tester.pumpAndSettle();
}

void main() {
  group('AdminApi', () {
    test('parses pending workers with their private documents', () async {
      final h = Harness(access: 'A');
      h.backend.on('GET /admin/workers/pending/', (_) => ok(paged([adminWorkerJson(docs: ['cnic_front'])])));
      final page = await AdminApi(h.client).pendingWorkers(search: 'bilal');
      final w = page.results.single;
      expect(w.profile.fullName, 'Bilal Ahmed');
      expect(w.documents.single.type, 'cnic_front');
      expect(w.hasBothCnicSides, isFalse);
      expect(h.backend.calls.single.url.queryParameters['search'], 'bilal');
    });

    test('suspend, reject and complaint updates send the reason to the server', () async {
      final h = Harness(access: 'A');
      h.backend.on('POST /admin/users/14/suspend/', (_) => ok(adminUserJson(suspended: true)));
      h.backend.on('POST /admin/workers/5/reject/', (_) => ok(adminWorkerJson()));
      h.backend.on('POST /admin/complaints/3/status/', (r) => ok({
            'id': 3, 'booking': 21, 'category': 'no_show', 'subject': 'Late', 'description': 'Never came',
            'status': jsonDecode(r.body)['status'], 'resolution': 'Refunded', 'created_at': '2026-11-24T10:00:00Z',
            'raised_by': 1, 'raised_by_name': 'Ayesha Khan', 'raised_by_role': 'customer',
            'against_user': 2, 'against_user_name': 'Bilal Ahmed', 'resolved_by': 4,
          }));
      final api = AdminApi(h.client);
      final u = await api.suspendUser(14, 'Fake jobs');
      expect(u.isSuspended, isTrue);
      await api.rejectWorker(5, 'Blurry CNIC');
      final c = await api.updateComplaint(3, 'resolved', 'Refunded');
      expect(c.complaint.status, 'resolved');
      expect(c.againstUserName, 'Bilal Ahmed');
      final bodies = [for (final r in h.backend.calls) jsonDecode(r.body)];
      expect(bodies[0], {'reason': 'Fake jobs'});
      expect(bodies[1], {'reason': 'Blurry CNIC'});
      expect(bodies[2], {'status': 'resolved', 'resolution': 'Refunded'});
    });
  });

  test('the 30-day chart fills days without bookings', () {
    final days = last30Days([
      {'date': '2026-11-24', 'bookings': 4},
      {'date': '2026-11-01', 'bookings': 2},
    ], today: DateTime(2026, 11, 24));
    expect(days, hasLength(30));
    expect(days.first, {'date': '2026-10-26', 'bookings': 0});
    expect(days.last, {'date': '2026-11-24', 'bookings': 4});
    expect(days.firstWhere((d) => d['date'] == '2026-11-01')['bookings'], 2);
  });

  group('admin dashboard', () {
    testWidgets('signs an admin into the overview with live numbers', (tester) async {
      final h = await adminHarness();
      await pumpAdmin(tester, h);
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.byKey(const Key('admin-logout')), findsOneWidget);
    });

    testWidgets('reviews a pending worker, rejects without a reason is blocked, then verifies', (tester) async {
      final h = await adminHarness();
      var pending = [adminWorkerJson()];
      h.backend.on('GET /admin/workers/pending/', (_) => ok(paged(pending)));
      h.backend.on('GET /admin/workers/5/', (_) => ok(adminWorkerJson()));
      h.backend.on('POST /admin/workers/5/verify/', (_) {
        pending = [];
        return ok({...adminWorkerJson(), 'verification_status': 'approved'});
      });
      await pumpAdmin(tester, h);

      await tester.tap(find.text('Verification').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pending-5')));
      await tester.pumpAndSettle();
      expect(find.text('CNIC 3520205992431'), findsOneWidget, reason: 'admins see the CNIC number');

      await tester.tap(find.byKey(const Key('reject-worker')));
      await tester.pumpAndSettle();
      final rejectButton = find.widgetWithText(FilledButton, 'Reject');
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNull, reason: 'a reason is required');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('verify-worker')));
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('POST /admin/workers/5/verify/'), hasLength(1));
      expect(find.byKey(const Key('pending-5')), findsNothing, reason: 'back on the queue, now empty');
    });

    testWidgets('verifying a worker with only one CNIC side asks first', (tester) async {
      final h = await adminHarness();
      h.backend.on('GET /admin/workers/pending/', (_) => ok(paged([adminWorkerJson(docs: ['cnic_front'])])));
      h.backend.on('GET /admin/workers/5/', (_) => ok(adminWorkerJson(docs: ['cnic_front'])));
      h.backend.on('POST /admin/workers/5/verify/', (_) => ok(adminWorkerJson()));
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Verification').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pending-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verify-worker')));
      await tester.pumpAndSettle();
      expect(find.text('CNIC is incomplete'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(h.backend.callsTo('POST /admin/workers/5/verify/'), isEmpty);
    });

    testWidgets('suspends a user with a reason', (tester) async {
      final h = await adminHarness();
      var suspended = false;
      h.backend.on('GET /admin/users/', (_) => ok(paged([adminUserJson(suspended: suspended)])));
      h.backend.on('POST /admin/users/14/suspend/', (r) {
        suspended = true;
        return ok(adminUserJson(suspended: true));
      });
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Users').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suspend-14')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Posting fake jobs');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/users/14/suspend/').single.body), {'reason': 'Posting fake jobs'});
      expect(find.text('Reactivate'), findsOneWidget);
    });

    testWidgets('changing the commission asks for confirmation and sends only what changed', (tester) async {
      final h = await adminHarness();
      var settings = {'commission_percent': '10.00', 'emergency_fee': '300.00', 'emergency_enabled': true,
          'updated_at': '2026-11-24T13:11:10+05:00'};
      h.backend.on('GET /admin/settings/', (_) => ok(settings));
      h.backend.on('PATCH /admin/settings/', (r) {
        settings = {...settings, ...(jsonDecode(r.body) as Map<String, dynamic>), 'updated_at': '2026-11-24T15:00:00+05:00'};
        return ok(settings);
      });
      await pumpAdmin(tester, h);
      tester.view.physicalSize = const Size(1400, 1600); // the whole settings form on screen
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('commission-percent')), '150');
      await tester.tap(find.byKey(const Key('save-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Enter 0 to 100'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('commission-percent')), '12.5');
      await tester.tap(find.byKey(const Key('save-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Change commission?'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('PATCH /admin/settings/').single.body), {'commission_percent': '12.5'});
    });

    testWidgets('resolves a complaint with a note', (tester) async {
      final h = await adminHarness();
      Map<String, dynamic> complaint(String status) => {
            'id': 3, 'booking': 21, 'category': 'no_show', 'subject': 'Worker never came', 'description': 'Waited 2 hours',
            'status': status, 'resolution': '', 'created_at': '2026-11-24T10:00:00Z',
            'raised_by': 1, 'raised_by_name': 'Ayesha Khan', 'raised_by_role': 'customer',
            'against_user': 2, 'against_user_name': 'Bilal Ahmed', 'resolved_by': null,
          };
      h.backend.on('GET /admin/complaints/', (_) => ok(paged([complaint('open')])));
      h.backend.on('POST /admin/complaints/3/status/', (_) => ok(complaint('resolved')));
      await pumpAdmin(tester, h);
      await tester.tap(find.text('Complaints').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complaint-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complaint-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolved').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('complaint-resolution')), 'Warned the worker');
      await tester.tap(find.byKey(const Key('save-complaint')));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.backend.callsTo('POST /admin/complaints/3/status/').single.body),
          {'status': 'resolved', 'resolution': 'Warned the worker'});
    });
  });
}
