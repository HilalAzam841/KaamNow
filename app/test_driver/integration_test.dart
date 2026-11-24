import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves screenshots taken on the phone to build/android-shots/ on the computer running the test.
Future<void> main() => integrationDriver(onScreenshot: (name, bytes, [args]) async {
      final f = File('build/android-shots/$name.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes);
      return true;
    });
