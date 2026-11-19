#!/usr/bin/env bash
set -euo pipefail
pkg=eugggeneee.journal
adb install -r build/app/outputs/flutter-apk/app-debug.apk
mkdir -p build/icon-review
for icon in default teal; do
  if [[ $icon != default ]]; then
    adb shell pm enable "$pkg/.Icon_$icon"
    adb shell pm disable "$pkg/.Icon_default"
  fi
  adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$pkg" | grep -F "Icon_$icon"
  adb shell am start -W -n "$pkg/.Icon_$icon" | grep -F 'Status: ok'
  adb shell input keyevent KEYCODE_HOME
  sleep 2
  adb shell input swipe 500 1500 500 300 320
  sleep 2
  adb exec-out screencap -p > "build/icon-review/android-$icon.png"
done
