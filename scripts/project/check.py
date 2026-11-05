#!/usr/bin/env python3
"""Проверки репозитория без Flutter: запускается перед коммитом и в CI.

  python3 scripts/project/check.py

Проверяет: импорты Dart, правила слоёв, неиспользуемые файлы, актуальность docs/GRAPH.md,
версию и заметки релиза, ссылки в Markdown, отсутствие эмодзи и мусора, пути скриптов в workflow.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import graph  # noqa: E402
import version  # noqa: E402

ROOT = graph.ROOT
SKIP_DIRS = {'.git', '.dart_tool', 'build', 'android', 'ios', 'node_modules'}
TEXT_SUFFIXES = {'.md', '.yml', '.yaml', '.py', '.dart', '.sh', '.json', '.txt', '.gitignore', '.gitattributes', '.editorconfig'}
EMOJI_RE = re.compile('[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u200D]')
JUNK_NAMES = {'.DS_Store', 'Thumbs.db', 'pubspec.lock', '.metadata'}
JUNK_SUFFIXES = ('.orig', '.rej', '.bak', '.tmp', '.swp', '.pyc', '.jks', '.keystore', '.p12', '.log')
FORBIDDEN_TEXT = ('mgtek', 'by.mgtek')


def files() -> list[Path]:
    out = []
    for p in sorted(ROOT.rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(ROOT)
        if set(rel.parts) & SKIP_DIRS or '__pycache__' in rel.parts:
            continue
        out.append(p)
    return out


def is_text(p: Path) -> bool:
    return p.suffix in TEXT_SUFFIXES or p.name in {'.gitignore', '.gitattributes', '.editorconfig', 'LICENSE'}


def check_dart() -> list[str]:
    g = graph.imports()
    out = [f'импорт не найден: {m}' for m in graph.missing_imports(g)]
    out += [f'правило слоёв: {v}' for v in graph.violations(g)]
    out += [f'файл нигде не используется: {o}' for o in graph.orphans(g)]
    text = graph.render(g)
    current = graph.OUT.read_text(encoding='utf-8') if graph.OUT.exists() else ''
    if current != text:
        out.append('docs/GRAPH.md устарел: python3 scripts/project/graph.py')
    return out


def check_hygiene() -> list[str]:
    out = []
    for p in files():
        rel = p.relative_to(ROOT).as_posix()
        if p.name in JUNK_NAMES or p.name.endswith(JUNK_SUFFIXES):
            out.append(f'мусорный файл: {rel}')
            continue
        if not is_text(p):
            continue
        text = p.read_text(encoding='utf-8')
        if rel != 'scripts/project/check.py':
            if EMOJI_RE.search(text):
                out.append(f'эмодзи в {rel}')
            for word in FORBIDDEN_TEXT:
                if word in text:
                    out.append(f'устаревший идентификатор «{word}» в {rel}')
        if text and not text.endswith('\n'):
            out.append(f'нет перевода строки в конце файла: {rel}')
        if '\r' in text:
            out.append(f'CRLF в {rel}')
    return out


def check_markdown_links() -> list[str]:
    out = []
    link = re.compile(r'\]\(([^)\s]+)\)')
    for p in files():
        if p.suffix != '.md':
            continue
        text = p.read_text(encoding='utf-8')
        text = re.sub(r'```.*?```', '', text, flags=re.S)
        for m in link.finditer(text):
            target = m.group(1)
            if target.startswith(('http://', 'https://', 'mailto:', '#')):
                continue
            path = (p.parent / target.split('#', 1)[0]).resolve()
            if not path.exists():
                out.append(f'{p.relative_to(ROOT).as_posix()}: битая ссылка {target}')
    return out


def check_workflows() -> list[str]:
    out = []
    for p in sorted((ROOT / '.github' / 'workflows').glob('*.yml')):
        text = p.read_text(encoding='utf-8')
        for m in re.finditer(r'(?:python3|bash)\s+(scripts/[\w./-]+)', text):
            if not (ROOT / m.group(1)).exists():
                out.append(f'{p.name}: нет скрипта {m.group(1)}')
    return out


def check_package_id() -> list[str]:
    out = []
    ci = (ROOT / '.github' / 'workflows' / 'ci.yml').read_text(encoding='utf-8')
    rel = (ROOT / '.github' / 'workflows' / 'release.yml').read_text(encoding='utf-8')
    for name, text in (('ci.yml', ci), ('release.yml', rel)):
        if 'APP_ORG: eugggeneee' not in text:
            out.append(f'{name}: APP_ORG должен быть eugggeneee')
    channel = "eugggeneee.journal/app_icon"
    for rel_path in ('lib/core/app_icons.dart', 'scripts/icons/setup_android.py', 'scripts/icons/setup_ios.py'):
        if channel not in (ROOT / rel_path).read_text(encoding='utf-8'):
            out.append(f'{rel_path}: канал значка должен называться {channel}')
    return out


def main() -> int:
    sections = [
        ('Dart', check_dart()),
        ('Версия', [f'версия: {e}' for e in version.check()]),
        ('Репозиторий', check_hygiene()),
        ('Ссылки', check_markdown_links()),
        ('Workflow', check_workflows()),
        ('Идентификатор пакета', check_package_id()),
    ]
    failed = False
    for title, problems in sections:
        if problems:
            failed = True
            print(f'[{title}]')
            for p in problems:
                print(f'  {p}')
    if failed:
        return 1
    print('Проверки пройдены')
    return 0


if __name__ == '__main__':
    sys.exit(main())
