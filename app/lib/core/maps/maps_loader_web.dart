import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<bool>? _loading;

/// Adds Google's Maps JavaScript API to the page once and waits for it.
Future<bool> loadGoogleMaps(String key) {
  if (_isLoaded()) return Future.value(true);
  return _loading ??= _load(key).then((ok) {
    if (!ok) _loading = null; // try again next time
    return ok;
  });
}

bool _isLoaded() {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  return google != null && google.has('maps');
}

Future<bool> _load(String key) {
  final done = Completer<bool>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(key)}'
    ..async = true;
  script.onload = ((web.Event _) {
    if (!done.isCompleted) done.complete(_isLoaded());
  }).toJS;
  script.onerror = ((web.Event _) {
    script.remove();
    if (!done.isCompleted) done.complete(false);
  }).toJS;
  web.document.head!.append(script);
  return done.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
}
