#!/usr/bin/env python3
"""Граф проекта: зависимости между модулями Dart, генерируется в docs/GRAPH.md.

  python3 scripts/project/graph.py            пересоздать docs/GRAPH.md
  python3 scripts/project/graph.py --check    проверить, что docs/GRAPH.md актуален, и правила слоёв

Вывод детерминированный (без дат), поэтому любое расхождение означает, что граф устарел.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs' / 'GRAPH.md'
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


def missing_imports(graph: dict[str, list[str]]) -> list[str]:
    return [f'{src} -> {dst}' for src, deps in graph.items() for dst in deps if not (ROOT / dst).exists()]


def violations(graph: dict[str, list[str]]) -> list[str]:
    out = []
    for name, prefix, banned in RULES:
        for src, deps in graph.items():
            if not src.startswith(prefix):
                continue
            for dst in deps:
                if dst.startswith(banned):
                    out.append(f'{name}: {src} -> {dst}')
    return out


def orphans(graph: dict[str, list[str]]) -> list[str]:
    used = {d for deps in graph.values() for d in deps}
    return [f for f in graph if f.startswith('lib/') and f != 'lib/main.dart' and f not in used]


def folder(path: str) -> str:
    return os.path.dirname(path)


def node_id(path: str) -> str:
    return re.sub(r'[^A-Za-z0-9]', '_', path)


def lines_of(path: str) -> int:
    return len((ROOT / path).read_text(encoding='utf-8').splitlines())


def render(graph: dict[str, list[str]]) -> str:
    folders = sorted({folder(f) for f in graph if f.startswith('lib/')})
    count = {d: sum(1 for f in graph if folder(f) == d) for d in folders}
    edges: dict[tuple[str, str], int] = {}
    for src, deps in graph.items():
        if not src.startswith('lib/'):
            continue
        for dst in deps:
            a, b = folder(src), folder(dst)
            if a != b and dst.startswith('lib/'):
                edges[(a, b)] = edges.get((a, b), 0) + 1

    out = [
        '# Граф проекта',
        '',
        'Файл создаётся скриптом `scripts/project/graph.py`. Вручную не редактируется.',
        'После любого изменения файлов в `lib/` и `test/` (создание, перенос, удаление, смена импортов) выполните:',
        '',
        '```bash',
        'python3 scripts/project/graph.py',
        '```',
        '',
        f'Файлов Dart: {sum(1 for f in graph if f.startswith("lib/"))} в `lib/`, '
        f'{sum(1 for f in graph if f.startswith("test/"))} в `test/`.',
        '',
        '## Папки',
        '',
        'Стрелка A --> B: файлы папки A импортируют файлы папки B. В скобках — число файлов.',
        '',
        '```mermaid',
        'flowchart LR',
    ]
    groups: dict[str, list[str]] = {}
    for d in folders:
        parts = d.split('/')
        top = parts[1] if len(parts) > 1 else 'root'
        groups.setdefault(top, []).append(d)
    for top in sorted(groups):
        out.append(f'  subgraph {node_id("g_" + top)}["{top}"]')
        for d in groups[top]:
            out.append(f'    {node_id(d)}["{d[4:] or "lib"} ({count[d]})"]')
        out.append('  end')
    for (a, b) in sorted(edges):
        out.append(f'  {node_id(a)} --> {node_id(b)}')
    out += ['```', '', '## Правила слоёв', '']
    for name, _, _ in RULES:
        out.append(f'- {name}')
    out += ['', '## Файлы', '', '| Файл | Строк | Импортирует | Используют |', '|---|---:|---:|---:|']
    used_by: dict[str, int] = {}
    for deps in graph.values():
        for d in deps:
            used_by[d] = used_by.get(d, 0) + 1
    for f in graph:
        if f.startswith('lib/'):
            out.append(f'| `{f[4:]}` | {lines_of(f)} | {len([d for d in graph[f] if d.startswith("lib/")])} | {used_by.get(f, 0)} |')
    out += ['', '## Зависимости папок', '']
    deps_by_folder: dict[str, set[str]] = {}
    for (a, b) in edges:
        deps_by_folder.setdefault(a, set()).add(b)
    for d in folders:
        targets = sorted(x[4:] for x in deps_by_folder.get(d, ()))
        out.append(f'- `{d[4:] or "lib"}` -> ' + (', '.join(f'`{t}`' for t in targets) if targets else 'нет'))
    out += ['', '## Тесты', '', '| Тест | Проверяет |', '|---|---|']
    for f in graph:
        if f.startswith('test/'):
            targets = ', '.join(f'`{d[4:]}`' for d in graph[f] if d.startswith('lib/')) or 'файлы проекта'
            out.append(f'| `{f[5:]}` | {targets} |')
    return '\n'.join(out) + '\n'


def main(argv: list[str]) -> int:
    graph = imports()
    text = render(graph)
    if '--check' in argv:
        problems = [f'импорт не найден: {m}' for m in missing_imports(graph)]
        problems += [f'нарушено правило: {v}' for v in violations(graph)]
        problems += [f'файл нигде не используется: {o}' for o in orphans(graph)]
        current = OUT.read_text(encoding='utf-8') if OUT.exists() else ''
        if current != text:
            problems.append('docs/GRAPH.md устарел: выполните python3 scripts/project/graph.py')
        for p in problems:
            print(p)
        return 1 if problems else 0
    OUT.write_text(text, encoding='utf-8')
    print(f'Обновлено: {OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
