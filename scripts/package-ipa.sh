#!/bin/bash
set -euo pipefail
mkdir -p build
xcodebuild archive -project Journal.xcodeproj -scheme Journal -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Journal.xcarchive \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee build/archive.log
APP='build/Journal.xcarchive/Products/Applications/Journal.app'
test -f "$APP/Journal"
mkdir -p build/ipa/Payload
ditto "$APP" build/ipa/Payload/Journal.app
(cd build/ipa && /usr/bin/zip -qry ../Journal.ipa Payload)
(cd build && shasum -a 256 Journal.ipa > SHA256SUMS)
python3 scripts/verify-ipa.py build/Journal.ipa
