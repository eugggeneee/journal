#!/usr/bin/env python3
"""Версия проекта: проверка и повышение по правилам docs/VERSIONING.md.

  python3 scripts/project/version.py show             текущая версия
  python3 scripts/project/version.py check            проверить pubspec.yaml, CHANGELOG и заметки релиза
  python3 scripts/project/version.py next             следующая версия по правилам (только вывод)
  python3 scripts/project/version.py bump patch       поднять версию (patch | minor | major)
  python3 scripts/project/version.py tag v1.0.0       проверить, что тег совпадает с pubspec.yaml

Схема MAJOR.MINOR.PATCH:
  PATCH  0..20  обычные обновления; после X.Y.20 следующей может быть только X.(Y+1).0
  MINOR         очень крупное обновление
  MAJOR         только полная переработка
Пред-релизы: X.Y.Z-beta.N и X.Y.Z-rc.N.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = ROOT / 'pubspec.yaml'
CHANGELOG = ROOT / 'CHANGELOG.md'
RELEASES = ROOT / '.github' / 'releases'

PATCH_MAX = 20
VERSION_RE = re.compile(r'^(\d+)\.(\d+)\.(\d+)(?:-(beta|rc)\.(\d+))?(?:\+(\d+))?$')
TAG_RE = re.compile(r'^v(\d+)\.(\d+)\.(\d+)(?:-(beta|rc)\.(\d+))?$')


def read_version() -> str:
    m = re.search(r'^version:\s*(\S+)\s*$', PUBSPEC.read_text(encoding='utf-8'), re.M)
    if not m:
        raise SystemExit('pubspec.yaml: не найдена строка version')
    return m.group(1)


def parse(version: str):
    m = VERSION_RE.match(version)
    if not m:
        return None
    major, minor, patch, pre, pre_n, build = m.groups()
    return int(major), int(minor), int(patch), pre, (int(pre_n) if pre_n else None), (int(build) if build else None)


def base(version: str) -> str:
    """Версия без номера сборки: 1.0.0-beta.1+3 -> 1.0.0-beta.1."""
    return version.split('+', 1)[0]


def validate(version: str) -> list[str]:
    p = parse(version)
    if p is None:
        return [f'версия «{version}» не соответствует схеме MAJOR.MINOR.PATCH[-beta.N|-rc.N][+BUILD]']
    major, minor, patch, pre, pre_n, _ = p
    errors = []
    if major < 1:
        errors.append('MAJOR должен быть не меньше 1')
    if patch > PATCH_MAX:
        errors.append(f'PATCH не может быть больше {PATCH_MAX}: следующая версия после {major}.{minor}.{PATCH_MAX} — {major}.{minor + 1}.0')
    if pre and (pre_n is None or pre_n < 1):
        errors.append('номер пред-релиза начинается с 1')
    return errors


def next_version(version: str, kind: str = 'patch') -> str:
    major, minor, patch, *_ = parse(version)  # type: ignore[misc]
    if kind == 'major':
        return f'{major + 1}.0.0'
    if kind == 'minor' or (kind == 'patch' and patch >= PATCH_MAX):
        return f'{major}.{minor + 1}.0'
    return f'{major}.{minor}.{patch + 1}'


def check() -> list[str]:
    version = read_version()
    errors = validate(version)
    if errors:
        return errors
    pre = parse(version)[3]
    stable = base(version)
    if not pre:
        log = CHANGELOG.read_text(encoding='utf-8')
        if not re.search(rf'^## \[{re.escape(stable)}\]', log, re.M):
            errors.append(f'CHANGELOG.md: нет раздела «## [{stable}]»')
        if not (RELEASES / f'v{stable}.md').exists():
            errors.append(f'нет файла заметок релиза .github/releases/v{stable}.md')
    return errors


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else 'check'
    if cmd == 'show':
        print(read_version())
        return 0
    if cmd == 'next':
        print(next_version(base(read_version())))
        return 0
    if cmd == 'check':
        errors = check()
        for e in errors:
            print(f'версия: {e}')
        return 1 if errors else 0
    if cmd == 'tag':
        tag = argv[2] if len(argv) > 2 else ''
        m = TAG_RE.match(tag)
        if not m:
            print(f'тег «{tag}» не соответствует схеме vMAJOR.MINOR.PATCH[-beta.N|-rc.N]')
            return 1
        errors = validate(tag[1:])
        if errors:
            print('; '.join(errors))
            return 1
        if tag[1:] != base(read_version()):
            print(f'тег {tag} не совпадает с версией в pubspec.yaml ({read_version()})')
            return 1
        return 0
    if cmd == 'bump':
        kind = argv[2] if len(argv) > 2 else ''
        if kind not in ('patch', 'minor', 'major'):
            print('использование: version.py bump patch|minor|major')
            return 1
        current = read_version()
        parsed = parse(current)
        if parsed is None:
            print(f'текущая версия «{current}» некорректна')
            return 1
        new = next_version(base(current), kind)
        build = (parsed[5] or 0) + 1
        text = PUBSPEC.read_text(encoding='utf-8')
        text = re.sub(r'^version:\s*\S+\s*$', f'version: {new}+{build}', text, count=1, flags=re.M)
        PUBSPEC.write_text(text, encoding='utf-8')
        print(f'{current} -> {new}+{build}')
        print('Дальше: раздел в CHANGELOG.md и файл .github/releases/v' + new + '.md (docs/RELEASING.md).')
        return 0
    print(__doc__)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
