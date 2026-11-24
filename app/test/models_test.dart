import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/models/models.dart';
import 'package:kaamnow/ui/account/notifications_screen.dart';

import 'helpers.dart';

void main() {
  test('parses a booking with price breakdown and contact', () {
    final b = Booking.fromJson(bookingJson(status: 'on_the_way'));
    expect(b.totalAmount, '1800.00');
    expect(b.worker.fullName, 'Bilal Ahmed');
    expect(b.worker.services.single.categoryName, 'Electrician');
    expect(b.contact['worker_phone'], '+923007654321');
    expect(b.isActive, isTrue);
    expect(b.statusHistory.single.toStatus, 'confirmed');
  });

  test('worker status steps follow the backend state machine', () {
    String? next(String s) => Booking.fromJson(bookingJson(status: s)).nextWorkerStatus;
    expect(next('confirmed'), 'on_the_way');
    expect(next('on_the_way'), 'arrived');
    expect(next('arrived'), 'in_progress');
    expect(next('in_progress'), isNull, reason: 'completion needs the customer code');
    expect(next('completed'), isNull);
  });

  test('parses offers with negotiation history and turn', () {
    final o = WorkerOffer.fromJson(offerJson());
    expect(o.awaiting, 'customer');
    expect(o.negotiations.map((n) => n.action), ['offer', 'counter']);
    expect(o.distanceKm, closeTo(2.4, 0.001));
  });

  test('page parsing works for paginated and plain lists', () {
    final paged = Paged.parse({'count': 41, 'next': 'http://x/?page=2', 'results': [requestJson()]}, ServiceRequest.fromJson);
    expect(paged.count, 41);
    expect(paged.hasMore, isTrue);
    final plain = Paged.parse([requestJson(), requestJson(id: 12)], ServiceRequest.fromJson);
    expect(plain.count, 2);
    expect(plain.hasMore, isFalse);
  });

  test('chat events from the socket work out which messages are mine', () {
    final mine = ChatMessage.fromEvent({'id': 1, 'sender': 5, 'body': 'hi', 'created_at': '2026-11-24T08:00:00Z'}, 5);
    final theirs = ChatMessage.fromEvent({'id': 2, 'sender': 9, 'body': 'hello'}, 5);
    expect(mine.isMine, isTrue);
    expect(theirs.isMine, isFalse);
  });

  test('client config reads emergency fee and payment availability', () {
    final c = ClientConfig.fromJson(configJson());
    expect(c.emergencyEnabled, isTrue);
    expect(c.emergencyFee, '300.00');
    expect({for (final m in c.paymentMethods) m.code: m.available}, {'cash': true, 'jazzcash': false});
  });

  test('notifications route to the right screen per role', () {
    AppNotification n(Map<String, dynamic> data, [String type = 'new_offer']) =>
        AppNotification(id: 1, type: type, title: '', body: '', data: data);
    expect(notificationTarget(n({'booking_id': 4}), isWorker: false), '/bookings/4');
    expect(notificationTarget(n({'request_id': 9, 'offer_id': 2}), isWorker: false), '/requests/9');
    expect(notificationTarget(n({'request_id': 9}), isWorker: true), '/jobs/9');
    expect(notificationTarget(n({}, 'verification'), isWorker: true), '/worker/profile');
    expect(notificationTarget(n({}, 'system'), isWorker: true), isNull);
  });
}
