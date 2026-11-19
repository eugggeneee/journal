#!/usr/bin/env bash
# Проверка двух опубликованных APK на чистом эмуляторе. root нужен только для тестовых данных.
set -euo pipefail
pkg=eugggeneee.journal
adb root
adb wait-for-device
adb install "$RUNNER_TEMP/$PREVIOUS/Journal-$PREVIOUS-android.apk"
adb shell am start -W -n "$pkg/.Icon_default"
adb shell am force-stop "$pkg"
prefs="/data/user/0/$pkg/shared_prefs"
file="$prefs/FlutterSharedPreferences.xml"
# Формат SharedPreferences и идентификаторы соответствуют настройкам прежнего приложения.
cat > "$RUNNER_TEMP/preferences.xml" <<'XML'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<map><string name="flutter.data_v1">{"version":3,"settings":{"group":"6312","onb":true,"tc":"teal","theme":2,"ho":["recent","tasks","metrics","week","tomorrow"],"hh":["metrics"]}}</string></map>
XML
uid=$(adb shell stat -c %u "/data/user/0/$pkg" | tr -d '\r')
adb shell mkdir -p "$prefs"
adb push "$RUNNER_TEMP/preferences.xml" "$file"
adb shell chown -R "$uid:$uid" "$prefs"
adb shell restorecon -R "$prefs"
adb shell pm enable "$pkg/.Icon_teal"
adb shell pm disable "$pkg/.Icon_default"
prefs_hash() { adb shell sha256sum "$file" | cut -d' ' -f1; }
active_icon() { adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$pkg"; }
active_icon | grep -F 'Icon_teal'
before=$(prefs_hash)
adb install -r "$RUNNER_TEMP/$TARGET/Journal-$TARGET-android.apk"
active_icon | grep -F 'Icon_teal'
[[ $(prefs_hash) == "$before" ]]
adb shell am start -W -n "$pkg/.Icon_teal"
sleep 5
adb shell pidof "$pkg"
adb shell dumpsys package "$pkg" | grep -F "versionName=${TARGET#v}"
