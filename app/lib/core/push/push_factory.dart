import 'push_platform.dart';

/// Outside the browser there is no web push. On the web, push_web.dart is used instead.
PushPlatform createPushPlatform() => const NoPushPlatform();
