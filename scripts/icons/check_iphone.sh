#!/usr/bin/env bash
set -euo pipefail
runtime=$1
app=$2
# Используем отдельное устройство для каждого запуска. Открываем Simulator до ожидания SpringBoard.
device=$(xcrun simctl create "Journal-$runtime" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "com.apple.CoreSimulator.SimRuntime.iOS-$runtime")
out="$PWD/build/icon-review/iphone-$runtime"
mkdir -p "$(dirname "$out")"
boot() {
  xcrun simctl boot "$device" && open -a "$(xcode-select -p)/Applications/Simulator.app" --args -CurrentDeviceUDID "$device" &&
    python3 - "$device" <<'PY'
import subprocess, sys
subprocess.run(['xcrun', 'simctl', 'bootstatus', sys.argv[1], '-b'], timeout=300, check=True)
PY
}
if ! boot; then
  xcrun simctl shutdown "$device"
  boot
fi
xcrun simctl install "$device" "$app"
xcrun simctl io "$device" screenshot "$out-default.png"
flutter run -d "$device" --no-pub --no-publish-port --use-application-binary="$app" --target scripts/icons/launcher_probe.dart --no-resident
data=$(xcrun simctl get_app_container "$device" eugggeneee.journal data)
wait_for_result() {
  for attempt in {1..35}; do
    marker=$(find "$data" -name journal-launcher-probe.txt -print -quit)
    if [[ -n "$marker" ]] && grep -q 'JOURNAL_LAUNCHER_' "$marker"; then return 0; fi
    sleep 2
  done
  return 1
}
if ! wait_for_result; then
  # UIKit может ждать закрытия своего окна, когда SpringBoard уже применил значок.
  xcrun simctl io "$device" screenshot "$out-confirmation.png"
  xcrun simctl terminate "$device" eugggeneee.journal
  SIMCTL_CHILD_JOURNAL_READ_ICON=1 xcrun simctl launch "$device" eugggeneee.journal
  wait_for_result
fi
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
