#!/usr/bin/env bash
set -euo pipefail

sim=$(xcrun simctl create Journal-upgrade com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-2)
trap 'xcrun simctl delete "$sim"' EXIT
xcrun simctl boot "$sim"
open -a "$(xcode-select -p)/Applications/Simulator.app" --args -CurrentDeviceUDID "$sim"
xcrun simctl bootstatus "$sim" -b
for stage in previous target; do
  app="$RUNNER_TEMP/journal-$stage"
  if [[ $stage == previous ]]; then tag=$PREVIOUS; else tag=$TARGET; fi
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-(beta|rc)\.[0-9]+)?$ ]]
  git fetch --depth=1 origin "refs/tags/$tag:refs/tags/$tag"
  mkdir "$app"
  git archive "$tag" | tar -x -C "$app"
  cp scripts/project/ios_upgrade_probe.dart "$app/lib/upgrade_probe.dart"
  (
    cd "$app"
    flutter create --platforms=ios --org eugggeneee --project-name journal .
    python3 scripts/icons/setup_ios.py
    flutter build ios --simulator --debug --target lib/upgrade_probe.dart \
      --dart-define=JOURNAL_UPGRADE_STAGE="$stage" --dart-define=JOURNAL_VERSION="${tag#v}"
  )
  xcrun simctl install "$sim" "$app/build/ios/iphonesimulator/Runner.app"
  (cd "$app" && flutter run -d "$sim" --no-pub --no-publish-port --no-resident \
    --use-application-binary=build/ios/iphonesimulator/Runner.app --target lib/upgrade_probe.dart)
  data=$(xcrun simctl get_app_container "$sim" eugggeneee.journal data)
  for _ in {1..90}; do
    marker=$(find "$data" -name "journal-upgrade-$stage.txt" -print -quit)
    [[ -n "$marker" && -s "$marker" ]] && break
    sleep 1
  done
  cat "$marker"
  [[ $(cat "$marker") == ok ]]
  xcrun simctl terminate "$sim" eugggeneee.journal
done
