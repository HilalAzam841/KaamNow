import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/app.dart';

import 'helpers.dart';

void main() {
  Future<Harness> signedInAs(String role) async {
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    h.backend.on('GET /auth/me/', (_) => ok(userJson(role: role)));
    await h.session.restore();
    return h;
  }

  test('while restoring, everything waits on the splash screen', () {
    final h = Harness();
    expect(redirectFor(h.session, '/bookings'), '/splash?from=%2Fbookings');
    expect(redirectFor(h.session, '/splash'), isNull);
  });

  test('signed-out users only reach login and register', () async {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    await h.session.restore();
    expect(redirectFor(h.session, '/bookings/3'), '/login?from=%2Fbookings%2F3');
    expect(redirectFor(h.session, '/register'), isNull);
  });

  test('customers land on home and cannot open worker screens', () async {
    final h = await signedInAs('customer');
    expect(redirectFor(h.session, '/login'), '/');
    expect(redirectFor(h.session, '/jobs'), '/');
    expect(redirectFor(h.session, '/worker/earnings'), '/');
    expect(redirectFor(h.session, '/requests/5'), isNull);
  });

  test('workers land on the job feed and cannot open customer screens', () async {
    final h = await signedInAs('worker');
    expect(redirectFor(h.session, '/splash'), '/jobs');
    expect(redirectFor(h.session, '/'), '/jobs');
    expect(redirectFor(h.session, '/requests'), '/jobs');
    expect(redirectFor(h.session, '/bookings/2'), isNull);
  });

  test('admins live in the admin dashboard', () async {
    final h = await signedInAs('admin');
    expect(redirectFor(h.session, '/'), '/admin');
    expect(redirectFor(h.session, '/login'), '/admin');
    expect(redirectFor(h.session, '/bookings/2'), '/admin');
    expect(redirectFor(h.session, '/admin'), isNull);
    expect(redirectFor(h.session, '/admin/workers/4'), isNull);
    expect(redirectFor(h.session, '/administrator'), '/admin');
  });

  test('until the number is confirmed, every screen leads to the SMS code screen (admins excepted)', () async {
    Future<Harness> as(String role, {bool verified = false}) async {
      final h = Harness(access: 'A', refresh: 'R');
      h.backend.on('GET /app/config/', (_) => ok({...configJson(), 'phone_verification': {'required': true, 'sms_available': true}}));
      h.backend.on('GET /auth/me/', (_) => ok({...userJson(role: role), 'phone_verified': verified}));
      await h.session.restore();
      return h;
    }

    final worker = await as('worker');
    expect(redirectFor(worker.session, '/jobs'), '/verify-phone');
    expect(redirectFor(worker.session, '/bookings/2'), '/verify-phone');
    expect(redirectFor(worker.session, '/verify-phone'), isNull);
    final done = await as('worker', verified: true);
    expect(redirectFor(done.session, '/jobs'), isNull);
    expect(redirectFor(done.session, '/verify-phone'), '/jobs');
    final admin = await as('admin');
    expect(redirectFor(admin.session, '/admin'), isNull);
  });

  test('an admin deep link survives the login screen', () async {
    final h = await signedInAs('admin');
    expect(redirectFor(h.session, '/login?from=%2Fadmin%2Fcomplaints'), '/admin/complaints');
  });

  test('customers and workers cannot open the admin dashboard', () async {
    final customer = await signedInAs('customer');
    expect(redirectFor(customer.session, '/admin'), '/');
    expect(redirectFor(customer.session, '/admin/users'), '/');
    final worker = await signedInAs('worker');
    expect(redirectFor(worker.session, '/admin/settings'), '/jobs');
  });

  test('the password-reset link opens whether signed in or out', () async {
    final out = Harness();
    out.backend.on('GET /app/config/', (_) => ok(configJson()));
    await out.session.restore();
    expect(redirectFor(out.session, '/reset-password?uid=MQ&token=abc'), isNull);
    final signedIn = await signedInAs('worker');
    expect(redirectFor(signedIn.session, '/reset-password?uid=MQ&token=abc'), isNull);
  });

  test('a stored but rejected token signs the user out', () async {
    final h = Harness(access: 'A', refresh: 'R');
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    h.backend.on('GET /auth/me/', (_) => err(401, 'not_authenticated', 'expired'));
    h.backend.on('POST /auth/token/refresh/', (_) => err(401, 'token_not_valid', 'blacklisted'));
    await h.session.restore();
    expect(h.session.isSignedIn, isFalse);
    expect(h.tokens.refresh, isNull);
  });

  test('a deep link survives the splash screen after a page reload', () async {
    final h = Harness(access: 'A', refresh: 'R');
    final toSplash = redirectFor(h.session, '/bookings/3');
    expect(toSplash, '/splash?from=%2Fbookings%2F3');
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    h.backend.on('GET /auth/me/', (_) => ok(userJson()));
    await h.session.restore();
    expect(redirectFor(h.session, toSplash!), '/bookings/3');
  });

  test('a signed-out deep link goes to login and back after signing in', () async {
    final h = Harness();
    h.backend.on('GET /app/config/', (_) => ok(configJson()));
    await h.session.restore();
    final toLogin = redirectFor(h.session, '/splash?from=%2Fbookings%2F3');
    expect(toLogin, '/login?from=%2Fbookings%2F3');
    h.backend.on('POST /auth/login/', (_) => ok({'user': userJson(), 'tokens': {'access': 'A', 'refresh': 'R'}}));
    await h.session.login('03001234567', 'pw');
    expect(redirectFor(h.session, toLogin!), '/bookings/3');
  });

  test('a deep link to a screen for the other role falls back to home, and external targets are ignored', () async {
    final h = await signedInAs('customer');
    expect(redirectFor(h.session, '/splash?from=%2Fworker%2Fearnings'), '/');
    expect(redirectFor(h.session, '/login?from=%2F%2Fevil.example'), '/');
  });
}
