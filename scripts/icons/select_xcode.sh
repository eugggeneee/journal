#!/usr/bin/env bash
set -euo pipefail
# Icon Composer и компилятор ресурсов должны принадлежать одному Xcode.
for app in /Applications/Xcode_26.3.app "$(xcode-select -p)/../.." /Applications/Xcode_26*.app; do
  if [[ -x "$app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" ]]; then
    sudo xcode-select --switch "$app/Contents/Developer"
    xcodebuild -version
    exit 0
  fi
done
echo "На сборщике не найден Xcode с Icon Composer" >&2
exit 1
