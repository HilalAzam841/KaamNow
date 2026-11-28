import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/admin/guarantee_screen.dart';
import 'package:kaamnow/ui/bookings/booking_detail_screen.dart';
import 'package:kaamnow/ui/bookings/guarantee_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_test.dart' show adminHarness, paged, pumpAdmin;
import 'favourites_test.dart' show tall;
import 'helpers.dart';
import 'promos_test.dart' show pumpScreen;

Map<String, dynamic> claimJson({String status = 'pending', bool canEscalate = false, String note = ''}) => {
      'id': 4, 'booking': 21, 'booking_title': 'Fan not working', 'customer_name': 'Ayesha',
      'worker_name': 'Bilal Ahmed', 'problem': 'The fan stopped again', 'status': status,
      'redo_time': status == 'accepted' ? '2026-11-30T07:00:00Z' : null, 'worker_note': note,
      'respond_by': '2026-11-30T09:00:00Z', 'accepted_at': null, 'redo_done_at': null, 'closed_at': null,
      'can_escalate': canEscalate, 'complaint_id': status == 'escalated' ? 12 : null,
      'created_at': '2026-11-28T09:00:00Z',
    };

Map<String, dynamic> doneBooking({bool canClaim = false, Map<String, dynamic>? claim}) => {
      ...bookingJson(status: 'completed'),
      'completed_at': '2026-11-27T09:00:00Z',
      'guarantee': {'until': '2026-12-04T09:00:00Z', 'can_claim': canClaim, 'claim': claim},
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  test('guarantee parses, and older servers mean no guarantee', () {
    final b = Booking.fromJson(doneBooking(claim: claimJson(status: 'declined', canEscalate: true, note: 'Not my work')));
    expect(b.guarantee.until, isNotNull);
    expect(b.guarantee.claim!.status, 'declined');
    expect(b.guarantee.claim!.canEscalate, isTrue);
    expect(b.guarantee.claim!.workerNote, 'Not my work');
    expect(Booking.fromJson(bookingJson()).guarantee.canClaim, isFalse);
    expect(Booking.fromJson(bookingJson()).guarantee.claim, isNull);
  });

  Future<Harness> open(WidgetTester tester, Map<String, dynamic> Function() booking,
      {String role = 'customer', void Function(Harness h)? setup}) {
    tall(tester);
    return pumpScreen(tester, const BookingDetailScreen(id: 21), role: role, setup: (h) {
      h.backend.on('GET /bookings/21/', (_) => ok(booking()));
      h.backend.on('GET /bookings/21/messages/', (_) => ok(paged([])));
      h.backend.on('GET /payments/', (_) => ok(paged([])));
      h.backend.on('GET /requests/11/', (_) => ok(requestJson(bookingId: 21)));
      setup?.call(h);
    });
  }

  testWidgets('the customer asks for a free fix', (tester) async {
    Map<String, dynamic>? claim;
    final h = await open(tester, () => doneBooking(canClaim: claim == null, claim: claim), setup: (h) {
      h.backend.on('POST /bookings/21/guarantee/', (req) {
        expect((jsonDecode(req.body) as Map)['problem'], 'The fan stopped again');
        claim = claimJson();
        return ok(claim, status: 201);
      });
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guarantee-claim')));
    expect(find.textContaining('guarantee until'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guarantee-claim')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'The fan stopped again');
    await tester.pump();
    await tester.tap(find.text('Send claim'));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /bookings/21/guarantee/'), hasLength(1));
    expect(find.byKey(const Key('guarantee-claim')), findsNothing);
    expect(find.text('Waiting for the worker to answer.'), findsOneWidget);
    expect(find.byKey(const Key('claim-withdraw')), findsOneWidget);
    expect(find.byKey(const Key('claim-escalate')), findsNothing, reason: 'the worker still has time');
  });

  testWidgets('the worker accepts and picks a time to come back', (tester) async {
    var claim = claimJson();
    final h = await open(tester, () => doneBooking(claim: claim), role: 'worker', setup: (h) {
      h.backend.on('POST /guarantee-claims/4/accept/', (req) {
        final at = DateTime.parse((jsonDecode(req.body) as Map)['redo_time'] as String);
        expect(at.isAfter(DateTime.now()), isTrue);
        expect(at.toLocal().hour, 15);
        claim = claimJson(status: 'accepted');
        return ok(claim);
      });
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Please answer by'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('claim-accept')));
    await tester.tap(find.byKey(const Key('claim-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('redo-day-2')));
    await tester.tap(find.byKey(const Key('redo-hour-15')));
    await tester.tap(find.byKey(const Key('redo-ok')));
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /guarantee-claims/4/accept/'), hasLength(1));
    expect(find.byKey(const Key('claim-redo-done')), findsOneWidget);
    expect(find.byKey(const Key('claim-accept')), findsNothing);
  });

  testWidgets('after a decline the customer can send it to the KaamNow team', (tester) async {
    var claim = claimJson(status: 'declined', canEscalate: true, note: 'The motor burnt out');
    final h = await open(tester, () => doneBooking(claim: claim), setup: (h) {
      h.backend.on('POST /guarantee-claims/4/escalate/', (req) {
        expect((jsonDecode(req.body) as Map)['details'], 'Same fault as before');
        claim = claimJson(status: 'escalated');
        return ok(claim);
      });
    });
    await tester.pumpAndSettle();
    expect(find.text('The worker declined the claim.'), findsOneWidget);
    expect(find.textContaining('The motor burnt out'), findsOneWidget);
    expect(find.byKey(const Key('claim-withdraw')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('claim-escalate')));
    await tester.tap(find.byKey(const Key('claim-escalate')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Same fault as before');
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(h.backend.callsTo('POST /guarantee-claims/4/escalate/'), hasLength(1));
    expect(find.textContaining('Sent to the KaamNow team'), findsOneWidget);
  });

  testWidgets('the redo time dialog never offers a time in the past', (tester) async {
    DateTime? picked;
    await pumpScreen(tester, Builder(builder: (context) => TextButton(
        onPressed: () async => picked = await showDialog<DateTime>(
            context: context, builder: (_) => RedoTimeDialog(now: DateTime(2026, 11, 28, 16))),
        child: const Text('open'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('redo-day-0')));
    await tester.tap(find.byKey(const Key('redo-hour-12')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('redo-ok'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('redo-hour-18')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('redo-ok')));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 11, 28, 18));
  });

  testWidgets('admin lists guarantee claims', (tester) async {
    final h = await adminHarness();
    h.backend.on('GET /admin/guarantee-claims/', (_) => ok(paged([claimJson(status: 'escalated')])));
    await pumpAdmin(tester, h);
    tester.view.physicalSize = const Size(1400, 2000);
    await tester.tap(find.text('Guarantee').first);
    await tester.pumpAndSettle();
    expect(find.byType(AdminGuaranteeScreen), findsOneWidget);
    expect(find.textContaining('Fan not working · Ayesha → Bilal Ahmed'), findsOneWidget);
    expect(find.textContaining('Complaint #12'), findsOneWidget);
  });
}
