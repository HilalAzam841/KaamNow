import 'package:kaamnow/models/models.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kaamnow/core/api_exception.dart';

import 'helpers.dart';

void main() {
  test('unwraps the success envelope and sends the bearer token', () async {
    final h = Harness(access: 'A1', refresh: 'R1');
    h.backend.on('GET /auth/me/', (req) {
      expect(req.headers['Authorization'], 'Bearer A1');
      return ok(userJson());
    });
    final me = await h.api.me();
    expect(me.fullName, 'Ayesha Khan');
  });

  test('validation errors become field errors with a readable message', () async {
    final h = Harness();
    h.backend.on('POST /auth/register/', (_) => err(400, 'validation_error', 'Invalid input.', {
          'phone': ['An account with this phone number already exists.'],
        }));
    try {
      await h.api.register(phone: '03001234567', password: 'secret123', fullName: 'Ali Raza', role: UserRole.customer);
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.statusCode, 400);
      expect(e.fieldErrors['phone'], contains('already exists'));
      expect(e.displayMessage, 'Phone: An account with this phone number already exists.');
    }
  });

  test('refreshes an expired access token once and retries the request', () async {
    final h = Harness(access: 'old', refresh: 'R1');
    h.backend.on('GET /auth/me/', (req) => req.headers['Authorization'] == 'Bearer new'
        ? ok(userJson())
        : err(401, 'not_authenticated', 'Token expired'));
    h.backend.on('POST /auth/token/refresh/', (req) {
      expect(jsonDecode(req.body), {'refresh': 'R1'});
      return ok({'access': 'new', 'refresh': 'R2'});
    });
    final me = await h.api.me();
    expect(me.id, 1);
    expect(h.tokens.access, 'new');
    expect(h.tokens.refresh, 'R2', reason: 'rotated refresh token is stored');
  });

  test('concurrent 401s share a single refresh call', () async {
    final h = Harness(access: 'old', refresh: 'R1');
    h.backend.on('GET /notifications/unread-count/', (req) =>
        req.headers['Authorization'] == 'Bearer new' ? ok({'unread': 2}) : err(401, 'x', 'expired'));
    h.backend.on('POST /auth/token/refresh/', (_) => ok({'access': 'new', 'refresh': 'R2'}));
    final results = await Future.wait([h.api.unreadCount(), h.api.unreadCount(), h.api.unreadCount()]);
    expect(results, [2, 2, 2]);
    expect(h.backend.callsTo('POST /auth/token/refresh/'), hasLength(1));
  });

  test('a failed refresh clears tokens and reports the expired session', () async {
    final h = Harness(access: 'old', refresh: 'bad');
    var expired = false;
    h.client.onSessionExpired = () => expired = true;
    h.backend.on('GET /auth/me/', (_) => err(401, 'not_authenticated', 'Token expired'));
    h.backend.on('POST /auth/token/refresh/', (_) => err(401, 'token_not_valid', 'Token is blacklisted'));
    await expectLater(h.api.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(expired, isTrue);
    expect(h.tokens.access, isNull);
    expect(h.tokens.refresh, isNull);
  });

  test('login does not send a stale token and does not try to refresh', () async {
    final h = Harness(access: 'stale', refresh: 'R1');
    h.backend.on('POST /auth/login/', (req) {
      expect(req.headers.containsKey('Authorization'), isFalse);
      return err(401, 'authentication_failed', 'Invalid phone number or password.');
    });
    await expectLater(h.api.login('03001234567', 'nope'), throwsA(isA<ApiException>()));
    expect(h.backend.callsTo('POST /auth/token/refresh/'), isEmpty);
  });

  test('network failures and non-JSON server errors map to friendly exceptions', () async {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => throw const SocketishException());
    await expectLater(h.api.appConfig(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network_error')));
    h.backend.on('GET /app/config/', (_) => http.Response('<html>Bad gateway</html>', 502));
    await expectLater(h.api.appConfig(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
  });

  test('query parameters skip nulls and empty values', () {
    final h = Harness();
    final u = h.client.uri('/requests/', {'scope': 'feed', 'status': null, 'search': ''});
    expect(u.toString(), 'http://api.test/api/v1/requests/?scope=feed');
  });

  test('multipart uploads are rebuilt when retried after a refresh', () async {
    final h = Harness(access: 'old', refresh: 'R1');
    var attempts = 0;
    h.backend.on('POST /requests/', (req) {
      attempts++;
      return req.headers['Authorization'] == 'Bearer new' ? ok(requestJson(), status: 201) : err(401, 'x', 'expired');
    });
    h.backend.on('POST /auth/token/refresh/', (_) => ok({'access': 'new'}));
    final r = await h.api.createRequest(category: 1, title: 'Fan not working', description: 'Stopped after power cut',
        latitude: 31.5, longitude: 74.3, address: 'House 1', preferredTime: DateTime.utc(2026, 11, 25, 10));
    expect(r.id, 11);
    expect(attempts, 2);
    expect(h.tokens.refresh, 'R1', reason: 'kept when the server does not rotate it');
  });
}

class SocketishException implements Exception {
  const SocketishException();
}

