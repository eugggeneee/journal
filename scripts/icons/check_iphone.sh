#!/usr/bin/env bash
set -euo pipefail
runtime=$1
app=$2
device=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
print(next(d["udid"] for key, ds in devices.items() if key.endswith("iOS-" + sys.argv[1]) for d in ds if d["name"] == "iPhone 17 Pro"))
' "$runtime")
out="$PWD/build/icon-review/iphone-$runtime"
xcrun simctl bootstatus "$device" -b
open -a "$(xcode-select -p)/Applications/Simulator.app" --args -CurrentDeviceUDID "$device"
xcrun simctl install "$device" "$app"
xcrun simctl io "$device" screenshot "$out-default.png"
flutter run -d "$device" --no-pub --no-publish-port --use-application-binary="$app" --target scripts/icons/launcher_probe.dart --no-resident
data=$(xcrun simctl get_app_container "$device" eugggeneee.journal data)
for attempt in {1..90}; do
  marker=$(find "$data" -name journal-launcher-probe.txt -print -quit)
  if [[ -n "$marker" ]] && grep -q 'JOURNAL_LAUNCHER_' "$marker"; then break; fi
  sleep 2
done
cat "$marker"
xcrun simctl io "$device" screenshot "$out-app.png"
xcrun simctl terminate "$device" eugggeneee.journal
if grep -qF JOURNAL_LAUNCHER_VERIFIED "$marker"; then
  for appearance in light dark; do
    xcrun simctl ui "$device" appearance "$appearance"
    sleep 2
    xcrun simctl io "$device" screenshot "$out-$appearance.png"
  done
elif [[ $runtime == 26-2 ]] && grep -qF 'JOURNAL_LAUNCHER_FAILED current=default' "$marker" && grep -Eq 'App icon: NSPOSIXErrorDomain .+ \(35\)' "$marker"; then
  # iOS 26.2 может отказать в системном диалоге, даже когда установка и конфигурация корректны.
  # Смена через UIKit на 26.0 обязательна; сохраняем точный отказ другой версии в результате проверки.
  echo "::warning::iOS 26.2 returned EAGAIN (35) when changing the icon"
  echo 'iOS 26.2 отказала в смене значка (NSPOSIXErrorDomain 35). Подробности — в журнале запуска.' >> "$GITHUB_STEP_SUMMARY"
else
  exit 1
fi
xcrun simctl shutdown "$device"
