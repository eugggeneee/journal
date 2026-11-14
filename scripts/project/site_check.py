"""Проверка сайта (папка site/): он должен совпадать с приложением.

Если менялось то, что показано на сайте (темы, лимиты, вкладки, возможности), сайт обновляется в том же коммите: docs/SITE.md.
"""
from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter
from html.parser import HTMLParser
from urllib.parse import urlparse

import layers

ROOT = layers.ROOT
SITE = ROOT / 'site'
FILES = ('index.html', 'styles.css', 'app.js', 'palette.js')
EXTERNAL = re.compile(r'(?:src|href)="(https?://[^"]+)"')
ALLOWED_HOSTS = ('github.com', 'eugggeneee.github.io', 'altstore.io', 'sideloadly.io')


class _PageStructure(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
        self.anchors = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get('id'):
            self.ids.append(attrs['id'])
        if tag == 'a' and attrs.get('href', '').startswith('#'):
            self.anchors.append(attrs['href'][1:])


def check_structure(html: str) -> list[str]:
    page = _PageStructure()
    page.feed(html)
    out = [f'site/index.html: повторяется id="{name}"' for name, count in Counter(page.ids).items() if count > 1]
    out += [f'site/index.html: якорь #{name} не найден' for name in page.anchors if name not in page.ids]
    return out


def _read(p) -> str:
    return p.read_text(encoding='utf-8')


def check() -> list[str]:
    out = []
    for name in FILES:
        if not (SITE / name).exists():
            out.append(f'site/{name}: файл не найден')
    if out:
        return out
    html, js = _read(SITE / 'index.html'), _read(SITE / 'app.js')
    out += check_structure(html)
    app = ROOT / 'lib'

    gen = ROOT / 'scripts' / 'site' / 'make_palette.py'
    if subprocess.run([sys.executable, str(gen), '--check'], capture_output=True).returncode != 0:
        out.append('site/palette.js не совпадает с lib/core/palette.dart: python3 scripts/site/make_palette.py')

    limits = _read(app / 'logic' / 'limits.dart')
    month = re.search(r'kMonthLimit\s*=\s*(\d+)', limits)
    sem = re.search(r'kSemesterLimit\s*=\s*(\d+)', limits)
    if month and sem:
        if f'{month.group(1)} часов в месяц и {sem.group(1)} в семестр' not in html:
            out.append('site/index.html: лимиты пропусков не совпадают с lib/logic/limits.dart')
        if f"6, {month.group(1)})" not in js or f"14, {sem.group(1)})" not in js:
            out.append('site/app.js: лимиты в экране «Пропуски» не совпадают с lib/logic/limits.dart')

    count = len(re.findall(r"ThemeChoice\('", _read(app / 'core' / 'palette.dart')))
    if f'<b>{count}</b><span>цветовых тем' not in html:
        out.append(f'site/index.html: число тем должно быть {count} (lib/core/palette.dart)')

    shell = _read(app / 'ui' / 'app' / 'shell.dart')
    for label in re.findall(r"Icons\.\w+, Icons\.\w+, '([^']+)'\)", shell):
        if f"'{label}'" not in js:
            out.append(f'site/app.js: нет вкладки «{label}» из lib/ui/app/shell.dart')

    version_re = re.compile(r'^version:\s*(\S+)', re.M)
    if not version_re.search(_read(ROOT / 'pubspec.yaml')):
        out.append('pubspec.yaml: нет версии')

    for name in ('index.html', 'app.js'):
        for url in EXTERNAL.findall(_read(SITE / name)):
            if urlparse(url).hostname not in ALLOWED_HOSTS:
                out.append(f'site/{name}: внешний адрес вне списка: {url}')
    if 'eugggeneee/journal' not in js:
        out.append('site/app.js: нет адреса репозитория для блока «Что нового»')
    return out
