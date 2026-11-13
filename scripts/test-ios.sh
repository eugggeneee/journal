#!/bin/bash
set -euo pipefail
mkdir -p build

# Select a real installed iPhone, preferring the newest stable iOS runtime.
SIMULATOR_ID=$(xcrun simctl list devices available --json | python3 -c '
import json,sys,re
devices=json.load(sys.stdin)["devices"]
candidates=[]
for runtime, rows in devices.items():
    match=re.search(r"iOS-(\d+)-(\d+)",runtime)
    if not match: continue
    version=tuple(map(int,match.groups()))
    if version[0] < 26: continue
    for d in rows:
        if d.get("isAvailable") and "iPhone" in d["name"]:
            candidates.append((version, "Pro" not in d["name"],d["udid"]))
if not candidates: sys.exit("No iOS 26+ iPhone simulator installed")
print(sorted(candidates,reverse=True)[0][2])')

xcrun simctl boot "$SIMULATOR_ID" || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl status_bar "$SIMULATOR_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcodebuild test -project Journal.xcodeproj -scheme Journal \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath build/DerivedData -resultBundlePath build/Journal.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee build/simulator.log

mkdir -p build/screenshots
xcrun xcresulttool export attachments --path build/Journal.xcresult --output-path build/screenshots

# Verify the iOS 18 fallback on a separate runtime when installed on the runner.
IOS18_ID=$(xcrun simctl list devices available --json | python3 -c '
import json,sys
for runtime,devices in json.load(sys.stdin)["devices"].items():
    if "iOS-18-" in runtime:
        for d in devices:
            if d.get("isAvailable") and "iPhone" in d["name"]:
                print(d["udid"]);sys.exit(0)
print("")')
if [[ -z "$IOS18_ID" ]]; then
  echo 'iOS 18 runtime is not installed; fallback runtime verification is still required.'
  exit 1
fi
xcrun simctl shutdown "$SIMULATOR_ID"
xcrun simctl boot "$IOS18_ID" || true
xcrun simctl bootstatus "$IOS18_ID" -b
xcodebuild test -project Journal.xcodeproj -scheme Journal \
  -destination "platform=iOS Simulator,id=$IOS18_ID" \
  -derivedDataPath build/DerivedData -resultBundlePath build/Journal-iOS18.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee build/ios18.log
