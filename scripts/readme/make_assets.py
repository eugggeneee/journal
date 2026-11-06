#!/usr/bin/env python3
"""Графика README в стиле Material 3: герой, заголовки разделов, схема приватности, кнопки.

  python3 scripts/readme/make_assets.py            # SVG (без зависимостей)
  python3 scripts/readme/make_assets.py --raster   # ещё themes.png и social-preview.png (нужны Pillow и Playwright)

Цвета тем берутся из lib/core/palette.dart, значки тем: assets/icons/preview.
Результат пишется в docs/images/readme.
"""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs' / 'images' / 'readme'

# Тональная схема Material 3 (тёмная) от семени 0xFF3B5BDB, то же семейство, что у приложения.
BG = '#121318'
SURF_LOW = '#1A1B21'
SURF = '#1E1F25'
SURF_HIGH = '#282A2F'
SURF_HIGHEST = '#33343A'
ON_SURF = '#E3E1E9'
ON_VAR = '#C6C5D0'
OUTLINE_VAR = '#45464F'
PRIMARY = '#BEC3FF'
ON_PRIMARY = '#1B2487'
PRIMARY_CONT = '#2F40AE'
ON_PRIMARY_CONT = '#DEE0FF'
SEC_CONT = '#424659'
ON_SEC_CONT = '#DFE1F9'
TERT = '#E9B9DA'
TERT_CONT = '#5B3D57'
ON_TERT_CONT = '#FFD7F1'
ERR_CONT = '#93000A'
ON_ERR_CONT = '#FFDAD6'
WARN = '#FFB59A'
AMBER_CONT = '#5D4200'
ON_AMBER_CONT = '#FFDEA6'
GREEN_CONT = '#005320'
ON_GREEN_CONT = '#9EF8A3'

FONT = "Roboto, -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

# Material Icons (Apache 2.0), сетка 24x24.
G = {
    'school': 'M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3z',
    'calendar': 'M9 11H7v2h2v-2zm4 0h-2v2h2v-2zm4 0h-2v2h2v-2zm2-7h-1V2h-2v2H8V2H6v2H5c-1.11 0-1.99.9-1.99 2L3 20c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V9h14v11z',
    'star': 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z',
    'busy': 'M9.31 17l2.44-2.44L14.19 17l1.06-1.06-2.44-2.44 2.44-2.44L14.19 10l-2.44 2.44L9.31 10l-1.06 1.06 2.44 2.44-2.44 2.44L9.31 17zM19 3h-1V1h-2v2H8V1H6v2H5c-1.11 0-1.99.9-1.99 2L3 19c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V8h14v11z',
    'download': 'M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z',
    'check': 'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z',
    'close': 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
    'lock': 'M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z',
    'palette': 'M12 2C6.49 2 2 6.49 2 12s4.49 10 10 10c1.38 0 2.5-1.12 2.5-2.5 0-.61-.23-1.2-.64-1.67-.08-.1-.13-.21-.13-.33 0-.28.22-.5.5-.5H16c3.31 0 6-2.69 6-6 0-4.96-4.49-9-10-9zm-5.5 9c-.83 0-1.5-.67-1.5-1.5S5.67 8 6.5 8 8 8.67 8 9.5 7.33 11 6.5 11zm3-4C8.67 7 8 6.33 8 5.5S8.67 4 9.5 4s1.5.67 1.5 1.5S10.33 7 9.5 7zm5 0c-.83 0-1.5-.67-1.5-1.5S13.67 4 14.5 4s1.5.67 1.5 1.5S15.33 7 14.5 7zm3 4c-.83 0-1.5-.67-1.5-1.5S16.67 8 17.5 8s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z',
    'code': 'M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z',
    'phone': 'M17 1.01L7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17 19H7V5h10v14z',
    'shield': 'M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z',
    'globe': 'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zm6.93 6h-2.95c-.32-1.25-.78-2.45-1.38-3.56 1.84.63 3.37 1.91 4.33 3.56zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2 0 .68.06 1.34.14 2H4.26zm.82 2h2.95c.32 1.25.78 2.45 1.38 3.56-1.84-.63-3.37-1.9-4.33-3.56zm2.95-8H5.08c.96-1.66 2.49-2.93 4.33-3.56C8.81 5.55 8.35 6.75 8.03 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82c-.43 1.43-1.08 2.76-1.91 3.96zM14.34 14H9.66c-.09-.66-.16-1.32-.16-2 0-.68.07-1.35.16-2h4.68c.09.65.16 1.32.16 2 0 .68-.07 1.34-.16 2zm.25 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95c-.96 1.65-2.49 2.93-4.33 3.56zM16.36 14c.08-.66.14-1.32.14-2 0-.68-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2h-3.38z',
    'book': 'M18 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zM6 4h5v8l-2.5-1.5L6 12V4z',
    'help': 'M11 18h2v-2h-2v2zm1-16C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-14c-2.21 0-4 1.79-4 4h2c0-1.1.9-2 2-2s2 .9 2 2c0 2-3 1.75-3 5h2c0-2.25 3-2.5 3-5 0-2.21-1.79-4-4-4z',
}


def glyph(name: str, x: float, y: float, size: float, fill: str) -> str:
    return f'<path transform="translate({x:g} {y:g}) scale({size / 24:.4f})" d="{G[name]}" fill="{fill}"/>'


def text_width(s: str, size: float, bold: bool = False) -> float:
    """Ширина с запасом по самому широкому шрифту (DejaVu): на GitHub текст получится уже."""
    try:
        from PIL import ImageFont
        name = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
        for d in ('/usr/share/fonts/truetype/dejavu/', '/Library/Fonts/', ''):
            try:
                return ImageFont.truetype(d + name, 100).getlength(s) * size / 100
            except OSError:
                continue
    except ImportError:
        pass
    return len(s) * size * (0.66 if bold else 0.6)


def seeds() -> list[tuple[str, str, str]]:
    src = (ROOT / 'lib' / 'core' / 'palette.dart').read_text(encoding='utf-8')
    rows = re.findall(r"ThemeChoice\('(\w+)', '([^']+)', Color\(0xFF([0-9A-Fa-f]{6})\)", src)
    return [(i, n, '#' + c.upper()) for i, n, c in rows]


def svg(w: int, h: int, title: str, desc: str, body: str, defs: str = '') -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        f'role="img" aria-labelledby="t d" font-family="{FONT}">\n'
        f'<title id="t">{title}</title>\n<desc id="d">{desc}</desc>\n'
        f'<defs>{defs}</defs>\n{body}\n</svg>\n'
    )


def write(name: str, content: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(content, encoding='utf-8', newline='\n')
    print('  ', name)


def chip(x: float, y: float, label: str, *, size: float = 20, fill: str = SURF_HIGH, fg: str = ON_SURF,
         icon: str | None = None, icon_fg: str = PRIMARY, h: float = 44) -> tuple[str, float]:
    pad = 18
    iw = 26 if icon else 0
    w = pad * 2 + iw + text_width(label, size) + 2
    out = f'<rect x="{x:g}" y="{y:g}" width="{w:.0f}" height="{h:g}" rx="{h / 2:g}" fill="{fill}"/>'
    tx = x + pad
    if icon:
        out += glyph(icon, tx, y + (h - 22) / 2, 22, icon_fg)
        tx += iw
    out += f'<text x="{tx:.0f}" y="{y + h / 2 + size * 0.35:.0f}" font-size="{size:g}" fill="{fg}" font-weight="500">{label}</text>'
    return out, w


def hero_group(seed_list: list[tuple[str, str, str]]) -> str:
    """Левая часть: имя, обещание, значки. Правая: орбита из 20 цветов тем и три карточки Material 3."""
    cx, cy, r = 930, 222, 200
    dots = ''
    for i, (_, _, color) in enumerate(seed_list):
        a = -math.pi / 2 + 2 * math.pi * i / len(seed_list)
        dots += f'<circle cx="{cx + r * math.cos(a):.1f}" cy="{cy + r * math.sin(a):.1f}" r="11" fill="{color}"/>'

    def card(y: float, rot: float, tile: str, tile_fg: str, ico: str, title: str, sub: str, extra: str = '') -> str:
        return (
            f'<g transform="translate(770 {y:g}) rotate({rot:g} 160 48)">'
            f'<rect x="0" y="8" width="320" height="96" rx="30" fill="#000" opacity=".28"/>'
            f'<rect width="320" height="96" rx="30" fill="{SURF_HIGH}"/>'
            f'<rect x="16" y="20" width="56" height="56" rx="18" fill="{tile}"/>'
            f'{glyph(ico, 28, 32, 32, tile_fg)}'
            f'<text x="90" y="44" font-size="24" font-weight="700" fill="{ON_SURF}">{title}</text>'
            f'<text x="90" y="70" font-size="18" fill="{ON_VAR}">{sub}</text>{extra}</g>'
        )

    grade = (f'<circle cx="276" cy="48" r="24" fill="{GREEN_CONT}"/>'
             f'<text x="276" y="57" font-size="26" font-weight="700" text-anchor="middle" fill="{ON_GREEN_CONT}">9</text>')
    bar = (f'<rect x="90" y="82" width="190" height="8" rx="4" fill="{SURF_HIGHEST}"/>'
           f'<rect x="90" y="82" width="133" height="8" rx="4" fill="{WARN}"/>')

    chips_svg = ''
    x = 64
    for label, ico in (('Android', 'check'), ('iPhone', 'check'), ('Офлайн', 'check'), ('Без рекламы', 'check')):
        c, w = chip(x, 352, label, icon=ico)
        chips_svg += c
        x += w + 12

    return (
        f'<circle cx="1010" cy="40" r="310" fill="{PRIMARY_CONT}" opacity=".34"/>'
        f'<circle cx="1190" cy="440" r="230" fill="{TERT_CONT}" opacity=".42"/>'
        f'<circle cx="-30" cy="470" r="170" fill="{SURF}"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{OUTLINE_VAR}" stroke-width="2" opacity=".7"/>'
        f'<g id="theme-orbit">{dots}</g>'
        f'<g id="cards">'
        f'{card(70, -3, PRIMARY_CONT, ON_PRIMARY_CONT, "calendar", "Расписание", "Пара 1 · Математика")}'
        f'{card(170, 2, TERT_CONT, ON_TERT_CONT, "star", "Оценки", "Шкала 1–10", grade)}'
        f'{card(270, -2, ERR_CONT, ON_ERR_CONT, "busy", "Пропуски", "7 из 10 ч в месяц", bar)}'
        f'</g>'
        # имя и обещание
        f'<clipPath id="tile"><rect x="64" y="56" width="92" height="92" rx="28"/></clipPath><g id="title-block">'
        f'<rect x="64" y="56" width="92" height="92" rx="28" fill="#171E32"/>'
        f'<g clip-path="url(#tile)"><circle cx="64" cy="56" r="30" fill="#26334F"/><circle cx="156" cy="148" r="30" fill="#26334F"/></g>'
        f'<path transform="translate(64 56) scale(.1797)" d="M153.333 272.127V310.53C153.333 320.507 158.8 329.8 167.547 334.583L235.88 371.893C244.08 376.403 253.92 376.403 262.12 371.893L330.453 334.583C339.2 329.8 344.667 320.507 344.667 310.53V272.127L262.12 317.227C253.92 321.737 244.08 321.737 235.88 317.227L153.333 272.127ZM235.88 140.107L120.67 202.973C111.24 208.167 111.24 221.833 120.67 227.027L235.88 289.893C244.08 294.403 253.92 294.403 262.12 289.893L372 229.897V310.667C372 318.183 378.15 324.333 385.667 324.333C393.183 324.333 399.333 318.183 399.333 310.667V223.063C399.333 218.007 396.6 213.497 392.227 211.037L262.12 140.107C253.92 135.733 244.08 135.733 235.88 140.107Z" fill="{PRIMARY}"/>'
        f'<text x="180" y="132" font-size="92" font-weight="800" letter-spacing="-2" fill="{ON_SURF}">Journal</text>'
        f'<rect x="64" y="168" width="244" height="40" rx="20" fill="{SEC_CONT}"/>'
        f'<text x="186" y="195" font-size="22" font-weight="600" text-anchor="middle" fill="{ON_SEC_CONT}">МГТЭК · Дневник</text>'
        f'<text x="64" y="268" font-size="40" font-weight="700" fill="{ON_SURF}">Расписание, оценки</text>'
        f'<text x="64" y="316" font-size="40" font-weight="700" fill="{ON_SURF}">и пропуски <tspan fill="{PRIMARY}">в одном месте</tspan></text>'
        f'{chips_svg}</g>'
    )


def hero(seed_list) -> str:
    body = (f'<clipPath id="c"><rect width="1200" height="440" rx="36"/></clipPath>'
            f'<g clip-path="url(#c)"><rect width="1200" height="440" fill="{BG}"/>{hero_group(seed_list)}</g>')
    return svg(1200, 440, 'Journal: МГТЭК, Дневник',
               'Журнал студента: расписание группы, оценки и пропуски в одном приложении. '
               'Вокруг карточек Material 3 расположены 20 цветовых тем приложения.', body)


def section(slug: str, title: str, ico: str, tint: str, on_tint: str, dot_from: int, seed_list) -> None:
    dots = ''
    for k in range(3):
        color = seed_list[(dot_from + k) % len(seed_list)][2]
        dots += f'<circle cx="{1120 + k * 26}" cy="52" r="9" fill="{color}"/>'
    body = (f'<rect width="1200" height="104" rx="36" fill="{SURF}"/>'
            f'<rect x="20" y="20" width="64" height="64" rx="22" fill="{tint}"/>{glyph(ico, 36, 36, 32, on_tint)}'
            f'<text x="108" y="68" font-size="42" font-weight="700" fill="{ON_SURF}">{title}</text>{dots}')
    write(f'section-{slug}.svg', svg(1200, 104, title, f'Заголовок раздела «{title}».', body))


def button(slug: str, line2: str, fill: str, fg: str, alt: str) -> None:
    body = (f'<rect width="430" height="120" rx="60" fill="{fill}"/>'
            f'<circle cx="76" cy="60" r="34" fill="{fg}" opacity=".14"/>{glyph("download", 52, 36, 48, fg)}'
            f'<text x="132" y="62" font-size="44" font-weight="700" fill="{fg}">Скачать</text>'
            f'<text x="133" y="94" font-size="30" font-weight="500" fill="{fg}" opacity=".86">{line2}</text>')
    write(f'btn-{slug}.svg', svg(430, 120, alt, alt, body))


def privacy() -> str:
    parts = []
    parts.append(f'<rect width="1200" height="352" rx="36" fill="{SURF_LOW}"/>')
    # сайт колледжа
    parts.append(f'<rect x="48" y="48" width="320" height="168" rx="32" fill="{SURF_HIGH}"/>'
                 f'<rect x="72" y="72" width="64" height="64" rx="22" fill="{PRIMARY_CONT}"/>{glyph("globe", 88, 88, 32, ON_PRIMARY_CONT)}'
                 f'<text x="72" y="172" font-size="28" font-weight="700" fill="{ON_SURF}">Сайт колледжа</text>'
                 f'<text x="72" y="200" font-size="20" fill="{ON_VAR}">общедоступная страница</text>')
    # единственный запрос
    parts.append(f'<path d="M372 132 H540" stroke="{PRIMARY}" stroke-width="4" stroke-linecap="round" stroke-dasharray="2 12"/>'
                 f'<path d="M524 116 L548 132 L524 148 Z" fill="{PRIMARY}"/>'
                 f'<text x="460" y="104" font-size="22" font-weight="600" text-anchor="middle" fill="{ON_SURF}">один запрос</text>'
                 f'<text x="460" y="176" font-size="20" text-anchor="middle" fill="{ON_VAR}">расписание</text>')
    # устройство
    parts.append(f'<rect x="572" y="48" width="580" height="168" rx="32" fill="{SURF_HIGH}"/>'
                 f'<rect x="596" y="68" width="56" height="56" rx="20" fill="{GREEN_CONT}"/>{glyph("phone", 610, 82, 28, ON_GREEN_CONT)}'
                 f'<text x="668" y="104" font-size="28" font-weight="700" fill="{ON_SURF}">Ваше устройство</text>'
                 f'<text x="668" y="130" font-size="20" fill="{ON_VAR}">всё хранится только здесь</text>')
    x = 596
    for label in ('Оценки', 'Пропуски', 'Настройки'):
        c, w = chip(x, 152, label, icon='lock', fill=SURF_HIGHEST, icon_fg=ON_GREEN_CONT)
        parts.append(c)
        x += w + 12
    # чего нет
    x = 48
    parts.append(f'<text x="48" y="276" font-size="20" font-weight="600" fill="{ON_VAR}">В приложении нет</text>')
    for label in ('аккаунтов', 'рекламы', 'аналитики'):
        c, w = chip(x, 292, label, icon='close', fill=ERR_CONT, fg=ON_ERR_CONT, icon_fg=ON_ERR_CONT)
        parts.append(c)
        x += w + 12
    return svg(1200, 352, 'Схема хранения данных',
               'Единственный сетевой запрос: загрузка расписания с сайта колледжа. Оценки, пропуски и настройки '
               'хранятся только на устройстве. В приложении нет аккаунтов, рекламы и аналитики.', ''.join(parts))


def raster() -> None:
    from PIL import Image, ImageDraw, ImageFont
    s = 2
    items = seeds()
    W, H = 1200, 372
    img = Image.new('RGBA', (W * s, H * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def hexrgb(c: str) -> tuple[int, int, int]:
        return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))  # type: ignore[return-value]

    d.rounded_rectangle((0, 0, W * s, H * s), radius=36 * s, fill=hexrgb(BG))
    inter = '/usr/share/fonts/opentype/inter/Inter-%s.otf'

    def font(weight: str, size: int):
        try:
            return ImageFont.truetype(inter % weight, size * s)
        except OSError:
            return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if weight == 'Bold' else ''), size * s)

    d.text((48 * s, 40 * s), '20 цветовых тем', font=font('Bold', 40), fill=hexrgb(ON_SURF))
    d.text((48 * s, 94 * s), 'Значок приложения меняется вместе с темой. На Android 12+ цвета берутся из обоев.',
           font=font('Regular', 22), fill=hexrgb(ON_VAR))
    size, gap = 88, 20
    x0 = (W - (10 * size + 9 * gap)) // 2
    for i, (ident, _, color) in enumerate(items):
        icon = Image.open(ROOT / 'assets' / 'icons' / 'preview' / f'{ident}.png').convert('RGBA')
        icon = icon.resize((size * s, size * s), Image.LANCZOS)
        col, row = i % 10, i // 10
        x, y = x0 + col * (size + gap), 150 + row * (size + gap)
        img.alpha_composite(icon, (x * s, y * s))
    img.save(OUT / 'themes.png', optimize=True)
    print('   themes.png')

    from playwright.sync_api import sync_playwright
    seed_list = items
    body = (f'<clipPath id="c"><rect width="1200" height="440" rx="36"/></clipPath>'
            f'<rect width="1280" height="640" fill="{BG}"/>'
            f'<circle cx="0" cy="0" r="380" fill="{PRIMARY_CONT}" opacity=".22"/>'
            f'<g transform="translate(40 80)"><g clip-path="url(#c)"><rect width="1200" height="440" fill="{SURF_LOW}"/>{hero_group(seed_list)}</g></g>'
            f'<text x="640" y="580" font-size="24" text-anchor="middle" font-family="{MONO}" fill="{ON_VAR}">github.com/eugggeneee/journal</text>')
    page = svg(1280, 640, 'Journal', 'Обложка репозитория Journal.', body)
    page = page.replace(f'font-family="{FONT}"', 'font-family="Inter, sans-serif"')
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={'width': 1280, 'height': 640}, device_scale_factor=1)
        pg.set_content(f'<body style="margin:0;background:{BG}">{page}</body>')
        pg.screenshot(path=str(OUT / 'social-preview.png'))
        b.close()
    print('   social-preview.png')


def main() -> int:
    seed_list = seeds()
    assert len(seed_list) == 20, 'ожидалось 20 тем в palette.dart'
    print('SVG:')
    write('hero.svg', hero(seed_list))
    button('android', 'для Android', PRIMARY, ON_PRIMARY, 'Скачать для Android')
    button('iphone', 'для iPhone', SEC_CONT, ON_SEC_CONT, 'Скачать для iPhone')
    section('features', 'Возможности', 'calendar', PRIMARY_CONT, ON_PRIMARY_CONT, 0, seed_list)
    section('themes', 'Темы', 'palette', TERT_CONT, ON_TERT_CONT, 6, seed_list)
    section('install', 'Установка', 'download', GREEN_CONT, ON_GREEN_CONT, 11, seed_list)
    section('privacy', 'Конфиденциальность', 'shield', SEC_CONT, ON_SEC_CONT, 14, seed_list)
    section('faq', 'Вопросы и ответы', 'help', AMBER_CONT, ON_AMBER_CONT, 2, seed_list)
    section('dev', 'Разработка', 'code', PRIMARY_CONT, ON_PRIMARY_CONT, 16, seed_list)
    section('docs', 'Документация', 'book', SEC_CONT, ON_SEC_CONT, 9, seed_list)
    write('privacy.svg', privacy())
    if '--raster' in sys.argv:
        print('PNG:')
        raster()
    return 0


if __name__ == '__main__':
    sys.exit(main())
