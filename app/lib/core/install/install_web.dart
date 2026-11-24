import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'install_platform.dart';

/// Reads `window.kaamnowInstall`, which web/index.html fills from the browser's
/// `beforeinstallprompt` and `appinstalled` events.
class WebInstallPlatform implements InstallPlatform {
  JSObject? get _state => web.window.getProperty<JSObject?>('kaamnowInstall'.toJS);
  JSObject? get _prompt => _state?.getProperty<JSObject?>('prompt'.toJS);

  @override
  bool get canPrompt => _prompt != null;

  @override
  bool get isStandalone {
    final s = _state;
    if (s == null) return false;
    return (s.getProperty<JSBoolean?>('standalone'.toJS)?.toDart ?? false) ||
        (s.getProperty<JSBoolean?>('installed'.toJS)?.toDart ?? false);
  }

  @override
  bool get isIos {
    final ua = web.window.navigator.userAgent;
    final iPadAsMac = ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
    return RegExp('iPhone|iPad|iPod').hasMatch(ua) || iPadAsMac;
  }

  @override
  Future<bool> prompt() async {
    final p = _prompt;
    if (p == null) return false;
    p.callMethod<JSAny?>('prompt'.toJS);
    final choice = await p.getProperty<JSPromise<JSObject>>('userChoice'.toJS).toDart;
    _state?.setProperty('prompt'.toJS, null); // a prompt can be used once
    return choice.getProperty<JSString?>('outcome'.toJS)?.toDart == 'accepted';
  }

  @override
  void listen(void Function() onChange) {
    web.window.addEventListener('kaamnow-install-changed', ((web.Event _) => onChange()).toJS);
  }
}

InstallPlatform createInstallPlatform() => WebInstallPlatform();
