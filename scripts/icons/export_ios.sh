#!/usr/bin/env bash
# Экспорт из тех же Icon Composer документов, которые Xcode включает в приложение.
set -euo pipefail
out="$PWD/build/icon-review"
mkdir -p "$out/preview"
src="$PWD/assets/icons/ios"
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
if "$ictool" "$src/AppIcon.icon" --export-preview iOS Light 1024 1024 1 "$out/logo.png"; then
  for icon in "$src"/*.icon; do
    id=$(basename "$icon" .icon); id=${id#Icon_}
    if [[ $id == AppIcon ]]; then id=default; fi
    "$ictool" "$icon" --export-preview iOS Light 128 128 1 "$out/preview/$id.png"
  done
  "$ictool" "$src/AppIcon.icon" --export-preview iOS Dark 128 128 1 "$out/dark.png"
  "$ictool" "$src/AppIcon.icon" --export-preview iOS Tinted 128 128 1 "$out/tinted.png" ||
    "$ictool" "$src/AppIcon.icon" --export-preview iOS TintedLight 128 128 1 "$out/tinted.png"
else
  # На виртуальных Mac без подходящего Metal-драйвера используем растры iPhone из actool.
  compiled=$(mktemp -d)
  inputs=("$src"/*.icon)
  flags=()
  for icon in "$src"/Icon_*.icon; do flags+=(--alternate-app-icon "$(basename "$icon" .icon)"); done
  xcrun actool "${inputs[@]}" --compile "$compiled" --platform iphoneos --minimum-deployment-target 13.0 \
    --target-device iphone --app-icon AppIcon "${flags[@]}" --standalone-icon-behavior all \
    --output-partial-info-plist "$compiled/Info.plist"
  python3 - "$compiled" "$out" <<'PY'
import pathlib, plistlib, subprocess, sys
src, out = map(pathlib.Path, sys.argv[1:])
icons = plistlib.loads((src / 'Info.plist').read_bytes())['CFBundleIcons']
variants = {'default': icons['CFBundlePrimaryIcon'], **{k.removeprefix('Icon_'): v for k, v in icons['CFBundleAlternateIcons'].items()}}
for name, info in variants.items():
    candidates = [p for base in info['CFBundleIconFiles'] for p in src.glob(base + '*.png')]
    if not candidates:
        raise RuntimeError(f'{name}: {info}, {list(src.iterdir())}')
    image = max(candidates, key=lambda p: int(subprocess.check_output(['sips', '-g', 'pixelWidth', str(p)], text=True).split()[-1]))
    if name == 'default':
        subprocess.run(['sips', '-s', 'format', 'png', str(image), '--out', str(out / 'logo.png')], check=True)
    subprocess.run(['sips', '-s', 'format', 'png', '-z', '128', '128', str(image), '--out', str(out / 'preview' / (name + '.png'))], check=True)
PY
fi
