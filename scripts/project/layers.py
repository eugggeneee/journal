#!/usr/bin/env python3
"""Импорты Dart и правила слоёв: разбор файлов `lib/` и `test/` для `check.py`.

Отдельно не запускается; ничего не генерирует и не записывает.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPORT_RE = re.compile(r"""^\s*(?:import|export)\s+'([^']+)'""", re.M)

FEATURES = ('absences', 'grades', 'schedule', 'profile', 'settings', 'onboarding')

# (имя правила, откуда, чему запрещено)
RULES = [
    ('core не зависит от data, logic и ui', 'lib/core/', ('lib/data/', 'lib/logic/', 'lib/ui/')),
    ('data не зависит от ui', 'lib/data/', ('lib/ui/',)),
    ('logic не зависит от ui', 'lib/logic/', ('lib/ui/',)),
    ('ui/kit не зависит от экранов', 'lib/ui/kit/', tuple(f'lib/ui/{f}/' for f in FEATURES)),
    ('lib не зависит от test', 'lib/', ('test/',)),
]


def dart_files() -> list[str]:
    files = []
    for top in ('lib', 'test'):
        for p in sorted((ROOT / top).rglob('*.dart')):
            files.append(p.relative_to(ROOT).as_posix())
    return files


def resolve(src: str, uri: str) -> str | None:
    """Путь внутреннего файла, на который указывает импорт (None — внешний пакет или dart:)."""
    if uri.startswith('package:journal/'):
        return 'lib/' + uri[len('package:journal/'):]
    if uri.startswith(('dart:', 'package:')):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(src), uri)).replace('\\', '/')


def imports() -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for f in dart_files():
        text = (ROOT / f).read_text(encoding='utf-8')
        deps = []
        for m in IMPORT_RE.finditer(text):
            target = resolve(f, m.group(1))
            if target:
                deps.append(target)
        result[f] = sorted(set(deps))
    return result


def missing_imports(deps_by_file: dict[str, list[str]]) -> list[str]:
    return [f'{src} -> {dst}' for src, deps in deps_by_file.items() for dst in deps if not (ROOT / dst).exists()]


def violations(deps_by_file: dict[str, list[str]]) -> list[str]:
    out = []
    for name, prefix, banned in RULES:
        for src, deps in deps_by_file.items():
            if not src.startswith(prefix):
                continue
            for dst in deps:
                if dst.startswith(banned):
                    out.append(f'{name}: {src} -> {dst}')
    return out


def orphans(deps_by_file: dict[str, list[str]]) -> list[str]:
    used = {d for deps in deps_by_file.values() for d in deps}
    return [f for f in deps_by_file if f.startswith('lib/') and f != 'lib/main.dart' and f not in used]
