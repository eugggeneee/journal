#!/usr/bin/env bash
# Экспорт из тех же Icon Composer документов, которые Xcode включает в приложение.
set -euo pipefail
out="$PWD/build/icon-review"
mkdir -p "$out/preview"
src="$PWD/assets/icons/ios"
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
render() {
  python3 - "$ictool" "$@" <<'PY'
from pathlib import Path
import subprocess, sys

command = sys.argv[1:]
output = Path(command[-1])
for attempt in range(3):
    try:
        result = subprocess.run(command, timeout=12)
    except subprocess.TimeoutExpired:
        print(f"Icon Composer stalled while exporting {output.name}, attempt {attempt + 1}", flush=True)
        continue
    if result.returncode == 0 and output.is_file() and output.stat().st_size:
        break
else:
    sys.exit(1)
PY
}
render_all() {
  render "$src/AppIcon.icon" --export-preview iOS Light 1024 1024 1 "$out/logo.png" || return 1
  for icon in "$src"/*.icon; do
    id=$(basename "$icon" .icon); id=${id#Icon_}
    if [[ $id == AppIcon ]]; then id=default; fi
    render "$icon" --export-preview iOS Light 128 128 1 "$out/preview/$id.png" || return 1
  done
}
if ! render_all; then
  # На виртуальных Mac без подходящего Metal-драйвера используем растры iPhone из actool.
  python3 - "$src" "$out" <<'PY'
from pathlib import Path
import subprocess, sys, tempfile

src, out = map(Path, sys.argv[1:])
for icon in sorted(src.glob('*.icon')):
    name = icon.stem
    key = 'default' if name == 'AppIcon' else name.removeprefix('Icon_')
    preview = out / 'preview' / (key + '.png')
    logo = out / 'logo.png'
    if preview.is_file() and (key != 'default' or logo.is_file()):
        continue
    # actool экспортирует отдельные PNG только для основного значка каталога.
    with tempfile.TemporaryDirectory() as directory:
        dest = Path(directory)
        subprocess.run(['xcrun', 'actool', str(icon), '--compile', directory, '--platform', 'iphoneos',
                        '--minimum-deployment-target', '13.0', '--target-device', 'iphone',
                        '--app-icon', name, '--standalone-icon-behavior', 'all',
                        '--output-partial-info-plist', str(dest / 'Info.plist')], check=True, timeout=90)
        images = list(dest.glob('*.png'))
        if not images:
            raise RuntimeError(f'actool не экспортировал {name}')
        image = max(images, key=lambda p: int(subprocess.check_output(
            ['sips', '-g', 'pixelWidth', str(p)], text=True).split()[-1]))
        if key == 'default' and not logo.exists():
            subprocess.run(['sips', '-s', 'format', 'png', str(image), '--out', str(logo)], check=True)
        subprocess.run(['sips', '-s', 'format', 'png', '-z', '128', '128', str(image),
                        '--out', str(preview)], check=True)
PY
fi

# Дополнительные варианты использует сама система. Сохраняем каждый нативный
# экспорт отдельно, чтобы сбой Metal в одном режиме не терял другие результаты.
for mode in Dark TintedLight TintedDark ClearLight ClearDark; do
  case "$mode" in
    Dark) name=dark ;;
    TintedLight) name=tinted ;;
    *) name=$mode ;;
  esac
  size=128
  if [[ $mode == Dark ]]; then size=1024; fi
  if ! render "$src/AppIcon.icon" --export-preview iOS "$mode" "$size" "$size" 1 "$out/$name.png"; then
    echo "::warning::Icon Composer could not flatten $mode on this runner; the native layered asset is verified during the simulator build."
    echo "$mode: нативный растровый экспорт недоступен на этом сборщике." >> "$GITHUB_STEP_SUMMARY"
  fi
done
