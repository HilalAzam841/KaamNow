import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/core/maps/google_maps.dart';
import 'package:kaamnow/models/models.dart';

import 'helpers.dart';

void main() {
  group('which map is shown', () {
    test('web uses Google Maps only when the server has a browser key', () {
      expect(MapProvider.useGoogle(browserKey: '', web: true), isFalse);
      expect(MapProvider.useGoogle(browserKey: 'AIzaWeb', web: true), isTrue);
    });

    test('phones use Google Maps only when the key is built into the app', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(MapProvider.useGoogle(browserKey: 'AIzaWeb', web: false, platform: p, appKey: ''), isFalse,
            reason: 'the browser key does not work in the native SDKs');
        expect(MapProvider.useGoogle(browserKey: '', web: false, platform: p, appKey: 'AIzaApp'), isTrue);
      }
    });

    test('desktop always uses OpenStreetMap', () {
      expect(MapProvider.useGoogle(browserKey: 'k', web: false, platform: TargetPlatform.linux, appKey: 'k'), isFalse);
    });

    test('this test build has no key, so screens show OpenStreetMap', () {
      expect(MapProvider.useGoogle(browserKey: ''), isFalse);
    });
  });

  test('app config carries the web key', () {
    expect(ClientConfig.fromJson(configJson()).googleMapsBrowserKey, '');
    final config = ClientConfig.fromJson({
      ...configJson(),
      'maps': {'provider': 'google', 'google_browser_key': 'AIzaWeb'},
    });
    expect(config.googleMapsBrowserKey, 'AIzaWeb');
  });
}
