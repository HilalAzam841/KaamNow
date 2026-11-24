#!/usr/bin/env bash
# Used by the GitHub "android" workflow: runs the Android integration test on the emulator and
# keeps a copy of the output (build/android-shots/drive.log), even if the run hangs or fails.
set -uo pipefail
mkdir -p build/android-shots
adb shell settings put global window_animation_scale 0 || true
timeout 20m flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 2>&1 | tee build/android-shots/drive.log
status=${PIPESTATUS[0]}
adb logcat -d -t 400 > build/android-shots/logcat.txt 2>&1 || true
exit "$status"
