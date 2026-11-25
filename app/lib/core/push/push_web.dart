import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'push_platform.dart';

@JS('JSON.stringify')
external JSString _stringify(JSAny? value);

/// Standard Web Push through the page's service worker (web/sw.js).
class WebPushPlatform implements PushPlatform {
  @override
  PushKind get kind => PushKind.web;

  // The service worker shows notifications and opens the screen itself (web/sw.js).
  @override
  void onOpen(void Function(String route) callback) {}
  @override
  void onForeground(void Function(ForegroundAlert alert) callback) {}

  bool _has(JSObject o, String name) => o.has(name);

  @override
  bool get supported =>
      _has(web.window.navigator, 'serviceWorker') && _has(web.window, 'PushManager') && _has(web.window, 'Notification');

  bool get _standalone => web.window.matchMedia('(display-mode: standalone)').matches;

  @override
  bool get needsInstallFirst {
    final ua = web.window.navigator.userAgent;
    final ios = RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
        (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
    return ios && !_standalone;
  }

  @override
  String get permission => _has(web.window, 'Notification') ? web.Notification.permission : 'denied';

  Future<web.ServiceWorkerRegistration> get _registration => web.window.navigator.serviceWorker.ready.toDart;

  Map<String, dynamic> _json(web.PushSubscription s) =>
      jsonDecode(_stringify(s.toJSON() as JSAny).toDart) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>?> current() async {
    if (!supported) return null;
    final sub = await (await _registration).pushManager.getSubscription().toDart;
    return sub == null ? null : _json(sub);
  }

  @override
  Future<Map<String, dynamic>?> subscribe(String publicKey) async {
    if (!supported) return null;
    final result = (await web.Notification.requestPermission().toDart).toDart;
    if (result != 'granted') return null;
    final key = base64Url.decode(base64Url.normalize(publicKey));
    final sub = await (await _registration)
        .pushManager
        .subscribe(web.PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: Uint8List.fromList(key).toJS))
        .toDart;
    return _json(sub);
  }

  @override
  Future<String?> unsubscribe() async {
    if (!supported) return null;
    final sub = await (await _registration).pushManager.getSubscription().toDart;
    if (sub == null) return null;
    final endpoint = sub.endpoint;
    await sub.unsubscribe().toDart;
    return endpoint;
  }

  @override
  void onResubscribe(void Function() callback) {
    if (!supported) return;
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      ((web.MessageEvent e) {
        final data = e.data;
        if (data != null && data.isA<JSObject>() && (data as JSObject).getProperty<JSString?>('type'.toJS)?.toDart == 'resubscribe') {
          callback();
        }
      }).toJS,
    );
  }
}

PushPlatform createPushPlatform() => WebPushPlatform();
