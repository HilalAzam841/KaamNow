import 'push_mobile.dart';
import 'push_platform.dart';

/// Android and iPhone apps use Firebase. On the web, push_web.dart is used instead.
PushPlatform createPushPlatform() => FirebasePushPlatform();
