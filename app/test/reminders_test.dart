import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/models/admin_models.dart';
import 'package:kaamnow/models/models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'helpers.dart';
import 'push_test.dart' show FakePushPlatform, openAccount, pumpSignedIn;
import 'package:kaamnow/core/push/push_controller.dart';

Map<String, dynamic> noShowJson({String review = 'open'}) => {
      'id': 4,
      'booking': 21,
      'booking_title': 'Fan not working',
      'preferred_time': '2026-11-25T10:00:00Z',
      'side': 'worker',
      'reported_by': 1,
      'reported_by_name': 'Ayesha Khan',
      'against': 9,
      'against_name': 'Bilal Ahmed',
      'against_role': 'worker',
      'against_total': 3,
      'note': 'Waited an hour',
      'review': review,
      'admin_note': '',
      'reviewed_at': null,
      'created_at': '2026-11-25T11:00:00Z',
    };

void main() {
  test('reminder and no-show fields parse', () {
    expect(User.fromJson(userJson()).bookingReminders, isTrue);
    expect(User.fromJson({...userJson(), 'booking_reminders': false}).bookingReminders, isFalse);
    final b = Booking.fromJson({
      ...bookingJson(),
      'no_show': {'reported': null, 'you_can_report': 'worker', 'opens_at': '2026-11-25T10:30:00Z'},
    });
    expect(b.canReportNoShow, 'worker');
    expect(b.noShowOpensAt, DateTime.utc(2026, 11, 25, 10, 30).toLocal());
    expect(Booking.fromJson(bookingJson()).canReportNoShow, isNull);
    expect(Booking.fromJson({...bookingJson(), 'no_show': {'reported': 'customer'}}).noShowReported, 'customer');
    final s = PlatformSettings.fromJson({'reminder_sms_enabled': true, 'no_show_grace_minutes': 45});
    expect(s.reminderSmsEnabled, isTrue);
    expect(s.noShowGraceMinutes, 45);
    expect(PlatformSettings.fromJson({}).noShowGraceMinutes, 30);
    final n = AdminNoShow.fromJson(noShowJson());
    expect(n.againstTotal, 3);
    expect(n.side, 'worker');
  });

  test('reporting a no-show posts the note', () async {
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('POST /bookings/21/no-show/', (_) => ok({
          ...bookingJson(status: 'cancelled'),
          'no_show': {'reported': 'worker', 'you_can_report': null, 'opens_at': null},
        }));
    final b = await h.session.api.reportNoShow(21, note: 'Waited an hour');
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/no-show/').single.body), {'note': 'Waited an hour'});
    expect(b.status, 'cancelled');
    expect(b.noShowReported, 'worker');
  });

  testWidgets('a customer turns job reminders off in Account', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await pumpSignedIn(tester, PushController(platform: FakePushPlatform()));
    h.backend.on('PATCH /auth/me/', (r) => ok({...userJson(), ...(jsonDecode(r.body) as Map<String, dynamic>)}));
    await openAccount(tester);
    final tile = find.byKey(const Key('reminders-switch'));
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('PATCH /auth/me/').single.body), {'booking_reminders': false});
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
  });

  testWidgets('admin reviews a no-show report', (tester) async {
    final h = await adminHarness();
    var review = 'open';
    h.backend.on('GET /admin/no-shows/', (_) => ok(paged([noShowJson(review: review)])));
    h.backend.on('POST /admin/no-shows/4/review/', (r) {
      review = (jsonDecode(r.body) as Map)['review'] as String;
      return ok(noShowJson(review: review));
    });
    await pumpAdmin(tester, h);
    await tester.tap(find.text('No-shows').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bilal Ahmed · worker did not come'), findsOneWidget);
    expect(find.textContaining('3 report(s) in total'), findsOneWidget);
    await tester.tap(find.byKey(const Key('no-show-4')));
    await tester.pumpAndSettle();
    expect(find.text('"Waited an hour"'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('no-show-note')), 'Called the worker, confirmed');
    await tester.tap(find.byKey(const Key('no-show-confirm')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /admin/no-shows/4/review/').single.body),
        {'review': 'confirmed', 'note': 'Called the worker, confirmed'});
  });

  testWidgets('admin switches on reminder SMS and changes the no-show wait', (tester) async {
    final h = await adminHarness();
    var settings = <String, dynamic>{'commission_percent': '10.00', 'emergency_fee': '300.00', 'emergency_enabled': true,
        'reminder_sms_enabled': false, 'no_show_grace_minutes': 30};
    h.backend.on('GET /admin/settings/', (_) => ok(settings));
    h.backend.on('PATCH /admin/settings/', (r) {
      settings = {...settings, ...(jsonDecode(r.body) as Map<String, dynamic>)};
      return ok(settings);
    });
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2200);
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-sms')));
    await tester.enterText(find.byKey(const Key('no-show-grace')), '5');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Enter 10 to 180'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('no-show-grace')), '45');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('PATCH /admin/settings/').single.body),
        {'reminder_sms_enabled': true, 'no_show_grace_minutes': 45});
  });
}
