#!/usr/bin/env python3
"""Собирает сайт в build/site: папка site/ плюс логотип и значки тем из assets (дубликатов в репозитории нет).

  python3 scripts/site/build.py
  python3 -m http.server -d build/site 8000
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / 'site'


def main() -> int:
    if subprocess.call([sys.executable, str(ROOT / 'scripts' / 'site' / 'make_palette.py'), '--check']) != 0:
        return 1
    if OUT.exists():
        shutil.rmtree(OUT)
    shutil.copytree(ROOT / 'site', OUT)
    assets = OUT / 'assets'
    (assets / 'icons').mkdir(parents=True)
    shutil.copy(ROOT / 'docs' / 'logo.png', assets / 'logo.png')
    for p in sorted((ROOT / 'assets' / 'icons' / 'preview').glob('*.png')):
        shutil.copy(p, assets / 'icons' / p.name)
    (OUT / '.nojekyll').write_text('', encoding='utf-8')
    print(f'Сайт собран: {OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
