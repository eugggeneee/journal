"""Проверка и сборка iOS-галереи стабильного релиза Journal."""
from datetime import datetime, timezone
from tempfile import TemporaryDirectory
import subprocess
import hashlib
import json
import shutil
import os
import sys
from pathlib import Path

from PIL import Image

from mockups import FINISHES, FRAMES, POSTERS, framed, poster_path, posters

SCENES = ('home-details date-picker schedule-menu grade-journal absence-calendar absence-journal home-compact schedule lesson mark absence-quick whole-day grades subject grade-form '
          'absences absence-form tasks task-form settings appearance theme-picker layout schedule-settings '
          'group bells-week bells-sat bells-short bell-editor absence-settings behavior data').split()


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'release'))
from altstore_source import verified_info


def record_build(output, tag, commit):
    repo = 'eugggeneee/journal'
    release = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/releases/tags/{tag}']))
    filename = f'Journal-{tag}-ios.ipa'
    with TemporaryDirectory() as tmp:
        subprocess.run(['gh', 'release', 'download', tag, '--repo', repo, '--pattern', filename,
                        '--dir', tmp], check=True)
        _, info = verified_info(release, Path(tmp) / filename)
    record = {'version': tag[1:], 'buildNumber': str(info['CFBundleVersion']), 'commit': commit,
              'rebuiltAt': datetime.now(timezone.utc).isoformat(timespec='seconds')}
    path = output / 'build.json'
    path.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8', newline='\n')
    return digest(path)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def recipe_hashes(scenes):
    tool = Path(__file__).resolve().parent
    spec = hashlib.sha256()
    for file in [tool / 'pack.py', tool / 'mockups.py', tool / 'record.py', tool / 'prepare.py', tool.parent / 'icons/artwork_palettes.json',
                 *(FRAMES / f'iphone-{finish}.png' for finish in FINISHES)]:
        data = file.read_bytes()
        if file.suffix == '.py':
            data = data.replace(b'\r\n', b'\n')
        spec.update(hashlib.sha256(data).digest())
    spec.update(json.dumps(scenes).encode())
    fixture = (tool / 'scenes.dart.in').read_text(encoding='utf-8')
    return {'specSHA256': spec.hexdigest(), 'fixtureSHA256': hashlib.sha256(fixture.encode()).hexdigest()}


def names(ids):
    return sorted(SCENES + [f'home-{key}' for key in ids] + [f'welcome-{i}' for i in range(1, 6)])


def media_names(scenes):
    kinds = ['raw', *(f'framed-{finish}' for finish in FINISHES)]
    return ({f'ios/{mode}/{scene}-{kind}.webp' for mode in ('light', 'dark')
             for scene in scenes for kind in kinds}
            | {f'frames/iphone-{finish}.png' for finish in FINISHES}
            | {poster_path(name, mode) for name in POSTERS for mode in FINISHES})


def complete(root, tag, scenes, commit):
    try:
        manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
        files = manifest['files']
        expected = media_names(scenes)
        build = json.loads((root / 'build.json').read_text(encoding='utf-8'))
        return (manifest['tag'] == tag and manifest.get('commit') == commit
                and manifest.get('buildSHA256') == digest(root / 'build.json')
                and build['version'] == tag[1:] and build['commit'] == commit
                and build['buildNumber'].isdigit() and datetime.fromisoformat(build['rebuiltAt']).tzinfo is not None
                and manifest.get('channel') == os.environ['CHANNEL']
                and all(manifest.get(k) == v for k, v in recipe_hashes(scenes).items())
                and manifest.get('spec') == 'gallery-v2' and manifest.get('fixture') == 'trade-0000-v1' and set(manifest['devices']) == {'ios'}
                and manifest['devices']['ios'] == {'model': 'iPhone 17', 'environment': 'iOS Simulator',
                    'os': '26.2', 'width': 1206, 'height': 2622}
                and manifest.get('group') == '0000' and manifest['scenes'] == scenes and set(files) == expected
                and {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
                == expected | {'manifest.json', 'build.json', 'README.md'}
                and all(digest(root / name) == files[name] for name in expected))
    except (OSError, KeyError, TypeError, ValueError):
        return False


def make(source, output, app, tag, commit):
    ids = json.loads((app / 'assets/icons/icons.json').read_text(encoding='utf-8'))
    scenes = names(ids)
    device = json.loads((source / 'device.json').read_text(encoding='utf-8'))
    if len(scenes) != 57 or len(set(scenes)) != 57:
        raise ValueError('gallery-v2 требует 57 различных сцен')
    size = None
    for mode in ('light', 'dark'):
        folder = source / mode
        if {p.stem for p in folder.glob('*.png')} != set(scenes):
            raise ValueError(f'Неполная съёмка iOS/{mode}')
        dest = output / 'ios' / mode
        dest.mkdir(parents=True)
        for name in scenes:
            with Image.open(folder / (name + '.png')) as png:
                raw = png.convert('RGB')
            size = size or raw.size
            if raw.size != size or raw.size != (1206, 2622) or raw.getbbox() is None:
                raise ValueError(f'Некорректный кадр {folder / name}')
            raw.save(dest / (name + '-raw.webp'), lossless=True, method=2)
            for finish in FINISHES:
                framed(raw, finish).save(dest / f'{name}-framed-{finish}.webp', quality=94, method=3)

    device['width'], device['height'] = size
    shutil.copytree(FRAMES, output / 'frames')
    for finish in FINISHES:
        with Image.open(output / 'frames' / f'iphone-{finish}.png') as frame:
            if frame.mode != 'RGBA' or frame.getpixel((0, 0))[3] or frame.getchannel('A').getextrema() != (0, 255):
                raise ValueError(f'Рамка {finish} должна иметь прозрачные поля')
    posters(output, app / 'docs/logo.png', os.environ['CHANNEL'])
    files = {key: digest(output / key) for key in sorted(media_names(scenes))}
    manifest = {**recipe_hashes(scenes), 'buildSHA256': record_build(output, tag, commit), 'spec': 'gallery-v2', 'fixture': 'trade-0000-v1', 'channel': os.environ['CHANNEL'], 'tag': tag, 'commit': commit, 'group': '0000', 'scenes': scenes,
                'devices': {'ios': device}, 'files': files}
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lines = [f'# Journal {tag} · iOS', '',
             f"{device['model']} · {device['environment']} · iOS {device['os']} · {size[0]} × {size[1]} px.",
             'Группа 0000. Все записи и имена вымышлены.', '',
             '[Версия, номер сборки и дата пересборки](build.json)', '',
             '[Светлая тема](ios/light/) · [Тёмная тема](ios/dark/) · [Рамки PNG](frames/) · [Фирменные макеты](mockups/)', '',
             'raw — исходный кадр. framed-light и framed-dark — светлый и тёмный корпус на прозрачном фоне.', '',
             '![Journal — расписание, главная и отметки](mockups/overview.webp)', '']
    (output / 'README.md').write_text('\n'.join(lines), encoding='utf-8')
    if not complete(output, tag, scenes, commit):
        raise ValueError('Не удалось подтвердить целостность галереи')


if __name__ == '__main__':
    if sys.argv[1] == 'check':
        ids = json.loads(Path(sys.argv[4]).read_text(encoding='utf-8'))
        print('true' if complete(Path(sys.argv[2]), sys.argv[3], names(ids), sys.argv[5]) else 'false')
    else:
        make(*(Path(s) for s in sys.argv[2:5]), *sys.argv[5:7])
