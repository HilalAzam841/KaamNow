import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/app.dart';
import 'package:kaamnow/models/admin_models.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/safety/safety.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> sharedJson({String status = 'on_the_way', bool location = true}) => {
      'title': 'Fan not working',
      'category_name': 'Electrician',
      'area': 'Gulberg',
      'status': status,
      'preferred_time': '2026-11-25T10:00:00Z',
      'duration_minutes': 120,
      'shared_by': 'customer',
      'customer_name': 'Ayesha',
      'worker': {'name': 'Bilal', 'is_verified': true, 'average_rating': '4.80', 'completed_jobs_count': 12},
      'on_the_way_at': '2026-11-25T09:40:00Z',
      'arrived_at': null,
      'started_at': null,
      'completed_at': null,
      'worker_location':
          location ? {'latitude': '31.500000', 'longitude': '74.300000', 'recorded_at': '2026-11-25T09:50:00Z'} : null,
      'expires_at': '2026-11-25T15:00:00Z',
    };

Map<String, dynamic> sosJson({String status = 'open'}) => {
      'id': 7,
      'booking': 21,
      'booking_title': 'Fan not working',
      'booking_status': 'arrived',
      'address': 'House 1, Gulberg',
      'role': 'customer',
      'raised_by': 1,
      'raised_by_name': 'Ayesha Khan',
      'raised_by_phone': '+923001234567',
      'other_party': {'name': 'Bilal Ahmed', 'phone': '+923007654321', 'role': 'worker'},
      'latitude': '31.510000',
      'longitude': '74.344000',
      'latest_worker_location': null,
      'note': 'He is shouting',
      'status': status,
      'contacts_texted': 2,
      'handled_by_name': null,
      'handled_at': null,
      'admin_note': '',
      'created_at': '2026-11-25T10:30:00Z',
    };

void big(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget opener(String label, Future<void> Function(BuildContext) onTap) =>
    Builder(builder: (context) => FilledButton(onPressed: () => onTap(context), child: Text(label)));

void main() {
  setUpAll(() => initializeDateFormatting());

  test('safety fields parse', () {
    final b = Booking.fromJson({
      ...bookingJson(),
      'safety': {'can_sos': true, 'sos_status': 'open', 'sharing_until': '2026-11-25T15:00:00Z'},
    });
    expect(b.canSos, isTrue);
    expect(b.sosStatus, 'open');
    expect(b.sharingUntil, DateTime.utc(2026, 11, 25, 15).toLocal());
    expect(Booking.fromJson(bookingJson()).canSos, isFalse);
    final j = SharedJob.fromJson(sharedJson());
    expect(j.workerName, 'Bilal');
    expect(j.workerLat, 31.5);
    expect(SharedJob.fromJson(sharedJson(location: false)).workerLat, isNull);
    final a = AdminSosAlert.fromJson(sosJson());
    expect(a.otherPhone, '+923007654321');
    expect(a.contactsTexted, 2);
  });

  test('a shared link opens without signing in', () async {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    await h.session.restore();
    expect(redirectFor(h.session, '/share/abc123'), isNull);
    expect(redirectFor(Harness().session, '/share/abc123'), isNull);
  });

  testWidgets('pressing SOS asks first, then alerts with the note', (tester) async {
    big(tester);
    var sent = false;
    final h = await pumpScreen(
      tester,
      opener('open', (c) async => sent = await showSosDialog(c, Booking.fromJson(bookingJson()))),
      setup: (h) => h.backend.on('POST /bookings/21/sos/', (_) => ok({'id': 7, 'contacts_texted': 2, 'status': 'open'})),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Need help?'), findsOneWidget);
    expect(find.textContaining('call 15 (police)'), findsOneWidget);
    // Cancelling sends nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /bookings/21/sos/'), isEmpty);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sos-note')), 'He is shouting');
    await tester.tap(find.byKey(const Key('send-sos')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /bookings/21/sos/').single.body), {'note': 'He is shouting'});
    expect(sent, isTrue);
    expect(find.textContaining('2 emergency contacts were texted.'), findsOneWidget);
  });

  testWidgets('sharing a job shows the link, texts contacts and can be turned off', (tester) async {
    big(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final h = await pumpScreen(
      tester,
      opener('share', (c) => showShareSheet(c, Booking.fromJson(bookingJson()))),
      setup: (h) {
        h.backend.on('POST /bookings/21/share/', (r) {
          final texts = (jsonDecode(r.body) as Map)['send_to_contacts'] == true;
          return ok({'url': 'https://app.kaamnow.pk/share/tok${texts ? 2 : 1}', 'expires_at': '2026-11-25T15:00:00Z',
              'contacts_texted': texts ? 1 : 0});
        });
        h.backend.on('DELETE /bookings/21/share/', (_) => ok(null));
      },
    );
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    expect(find.text('https://app.kaamnow.pk/share/tok1'), findsOneWidget);
    expect(find.textContaining('never shows phone numbers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy-share')));
    await tester.pumpAndSettle();
    expect(copied, 'https://app.kaamnow.pk/share/tok1');
    await tester.tap(find.byKey(const Key('text-contacts')));
    await tester.pumpAndSettle();
    expect(find.text('https://app.kaamnow.pk/share/tok2'), findsOneWidget);
    expect(find.text('1 emergency contact was texted.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop-sharing')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('DELETE /bookings/21/share/'), hasLength(1));
    expect(find.byKey(const Key('share-url')), findsNothing);
  });

  testWidgets('emergency contacts: add up to 3 and remove', (tester) async {
    big(tester);
    final contacts = <Map<String, dynamic>>[
      {'id': 1, 'name': 'Ammi', 'phone': '+923001112223'},
    ];
    final h = await pumpScreen(tester, const EmergencyContactsScreen(), setup: (h) {
      h.backend.on('GET /safety/contacts/', (_) => ok(contacts));
      h.backend.on('POST /safety/contacts/', (r) {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        contacts.add({'id': contacts.length + 5, 'name': b['name'], 'phone': '+923004445556'});
        return ok(contacts.last);
      });
      h.backend.on('DELETE /safety/contacts/1/', (_) {
        contacts.removeAt(0);
        return ok(null);
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('Ammi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-contact')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-name')), 'Bhai');
    await tester.enterText(find.byKey(const Key('contact-phone')), '0300 4445556');
    await tester.tap(find.byKey(const Key('save-contact')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /safety/contacts/').single.body),
        {'name': 'Bhai', 'phone': '0300 4445556'});
    expect(find.text('Bhai'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-contact-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Ammi'), findsNothing);
  });

  testWidgets('family sees the job and the worker on the map, or a clear message', (tester) async {
    big(tester);
    await pumpScreen(tester, const SharedJobScreen(token: 'tok1'),
        setup: (h) => h.backend.on('GET /safety/shared/tok1/', (_) => ok(sharedJson())));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ayesha shared this job with you'), findsOneWidget);
    expect(find.text('Worker: Bilal'), findsOneWidget);
    expect(find.text('Verified by KaamNow'), findsOneWidget);
    expect(find.byKey(const Key('shared-map')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await pumpScreen(tester, const SharedJobScreen(token: 'gone'),
        setup: (h) => h.backend.on('GET /safety/shared/gone/', (_) => err(404, 'not_found', 'Not found.')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('This link has expired or was turned off.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin acknowledges then resolves an SOS', (tester) async {
    final h = await adminHarness();
    var status = 'open';
    h.backend.on('GET /admin/sos-alerts/', (_) => ok(paged([sosJson(status: status)])));
    h.backend.on('POST /admin/sos-alerts/7/handle/', (r) {
      status = (jsonDecode(r.body) as Map)['status'] as String;
      return ok(sosJson(status: status));
    });
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2000);
    await tester.tap(find.text('SOS alerts').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayesha Khan (customer)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sos-7')));
    await tester.pumpAndSettle();
    expect(find.text('+923007654321'), findsOneWidget);
    expect(find.text('"He is shouting"'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sos-admin-note')), 'Called both');
    await tester.tap(find.byKey(const Key('sos-acknowledge')));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.backend.callsTo('POST /admin/sos-alerts/7/handle/').single.body),
        {'status': 'acknowledged', 'note': 'Called both'});
  });
}
