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

  test('admins are sent to the admin notice', () async {
    final h = await signedInAs('admin');
    expect(redirectFor(h.session, '/'), '/admin');
    expect(redirectFor(h.session, '/admin'), isNull);
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
