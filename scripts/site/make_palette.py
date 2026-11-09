#!/usr/bin/env python3
"""Генерирует site/palette.js из lib/core/palette.dart: те же 20 тем и те же роли Material 3.

  python3 scripts/site/make_palette.py          записать site/palette.js
  python3 scripts/site/make_palette.py --check  только проверить, что файл актуален

Цвета считаются так же, как ColorScheme.fromSeed (вариант tonalSpot, у чёрно-белой темы monochrome):
палитры HCT и тона ролей по спецификации Material 3.
"""
from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'lib' / 'core' / 'palette.dart'
OUT = ROOT / 'site' / 'palette.js'

# ───────── CAM16 / HCT ─────────
M16 = [[0.401288, 0.650173, -0.051461], [-0.250268, 1.204414, 0.045854], [-0.002079, 0.048952, 0.953127]]
M16I = [[1.86206786, -1.01125463, 0.14918677], [0.38752654, 0.62144744, -0.00897398], [-0.0158415, -0.03412294, 1.04996444]]
S2X = [[0.41233895, 0.35762064, 0.18051042], [0.2126, 0.7152, 0.0722], [0.01932141, 0.11916382, 0.95034478]]
X2S = [[3.2413774792388685, -1.5376652402851851, -0.49885366846268053], [-0.9691452513005321, 1.8758853451067872, 0.04156585616912061], [0.05562093689691305, -0.20395524564742123, 1.0571799111220335]]
WHITE = [95.047, 100.0, 108.883]


def mul(m, v):
    return [sum(m[i][j] * v[j] for j in range(3)) for i in range(3)]


def lin(c):
    c /= 255
    return 100 * (c / 12.92 if c <= 0.040045 else ((c + 0.055) / 1.055) ** 2.4)


def delin(v):
    v /= 100
    c = v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055
    return c * 255


def y_from_lstar(l):
    f = (l + 16) / 116
    return 100 * (f ** 3 if f ** 3 > 216 / 24389 else (116 * f - 16) / (24389 / 27))


def lstar_from_y(y):
    y /= 100
    return 116 * (y ** (1 / 3)) - 16 if y > 216 / 24389 else y * 24389 / 27


class VC:
    def __init__(self):
        self.la = 200 / math.pi * y_from_lstar(50) / 100
        rgb_w = mul(M16, WHITE)
        self.f = 1.0
        self.c = 0.69
        self.nc = 1.0
        d = max(0, min(1, self.f * (1 - 1 / 3.6 * math.exp((-self.la - 42) / 92))))
        self.d_rgb = [d * WHITE[1] / x + 1 - d for x in rgb_w]
        k = 1 / (5 * self.la + 1)
        k4 = k ** 4
        self.fl = k4 * self.la + 0.1 * (1 - k4) ** 2 * (5 * self.la) ** (1 / 3)
        self.n = y_from_lstar(50) / WHITE[1]
        self.z = 1.48 + math.sqrt(self.n)
        self.nbb = 0.725 / self.n ** 0.2
        self.ncb = self.nbb
        adapted = [(self.fl * self.d_rgb[i] * rgb_w[i] / 100) ** 0.42 for i in range(3)]
        a = [400 * x / (x + 27.13) for x in adapted]
        self.aw = (2 * a[0] + a[1] + 0.05 * a[2]) * self.nbb


V = VC()


def cam_from_argb(r, g, b):
    xyz = mul(S2X, [lin(r), lin(g), lin(b)])
    rgb = mul(M16, xyz)
    ad = []
    for i in range(3):
        x = (V.fl * V.d_rgb[i] * abs(rgb[i]) / 100) ** 0.42
        ad.append(math.copysign(400 * x / (x + 27.13), rgb[i]))
    a = (11 * ad[0] - 12 * ad[1] + ad[2]) / 11
    bb = (ad[0] + ad[1] - 2 * ad[2]) / 9
    hue = math.degrees(math.atan2(bb, a)) % 360
    return hue


def solve(hue, chroma, tone):
    """Цвет с заданными тоном (L*) и оттенком; хрома урезается до границы sRGB."""
    if chroma < 0.0001 or tone < 0.0001 or tone > 99.9999:
        v = round(delin(y_from_lstar(tone)))
        return (v, v, v)
    y_t = y_from_lstar(tone)
    hr = math.radians(hue)
    ecc = 0.25 * (math.cos(hr + 2) + 3.8)

    def inverse(j, c):
        if j <= 0:
            return None
        alpha = 0 if c == 0 else c / math.sqrt(j / 100)
        t = (alpha / (1.64 - 0.29 ** V.n) ** 0.73) ** (1 / 0.9)
        ac = V.aw * (j / 100) ** (1 / V.c / V.z)
        p1 = 50000 / 13 * ecc * V.nc * V.ncb
        p2 = ac / V.nbb
        g = 23 * (p2 + 0.305) * t / (23 * p1 + 11 * t * math.cos(hr) + 108 * t * math.sin(hr))
        a, b = g * math.cos(hr), g * math.sin(hr)
        ra = (460 * p2 + 451 * a + 288 * b) / 1403
        ga = (460 * p2 - 891 * a - 261 * b) / 1403
        ba = (460 * p2 - 220 * a - 6300 * b) / 1403
        out = []
        for x in (ra, ga, ba):
            ab = abs(x)
            base = max(0, 27.13 * ab / (400 - ab))
            out.append(math.copysign(100 / V.fl * base ** (1 / 0.42), x))
        rgb_c = [out[i] / V.d_rgb[i] for i in range(3)]
        xyz = mul(M16I, rgb_c)
        return mul(X2S, xyz), xyz[1]

    c = chroma
    while c >= 0:
        lo, hi = 0.0, 100.0
        res = None
        for _ in range(60):
            mid = (lo + hi) / 2
            r = inverse(mid, c)
            if r is None:
                lo = mid
                continue
            res = r
            if r[1] < y_t:
                lo = mid
            else:
                hi = mid
        r = inverse((lo + hi) / 2, c)
        if r and all(-0.5 <= x <= 100.5 for x in r[0]):
            return tuple(max(0, min(255, round(delin(max(0, min(100, x)))))) for x in r[0])
        c -= 0.5
    v = round(delin(y_t))
    return (v, v, v)


def hexs(rgb):
    return '#%02X%02X%02X' % rgb


# ───────── схема ─────────
def scheme(seed: str, mono: bool, dark: bool) -> dict[str, str]:
    r, g, b = (int(seed[i:i + 2], 16) for i in (0, 2, 4))
    hue = cam_from_argb(r, g, b)
    spec = [('p', hue, 36), ('s', hue, 16), ('t', (hue + 60) % 360, 24), ('n', hue, 6), ('nv', hue, 8)]
    if mono:
        spec = [(k, h, 0) for k, h, _ in spec]
    pal = {k: (h, c) for k, h, c in spec}

    def T(k, tone):
        return hexs(solve(pal[k][0], pal[k][1], tone))

    def pick(l, d):
        return d if dark else l

    out = {
        'surface': T('n', pick(98, 6)),
        'surfaceContainerLow': T('n', pick(96, 10)),
        'surfaceContainer': T('n', pick(94, 12)),
        'surfaceContainerHigh': T('n', pick(92, 17)),
        'surfaceContainerHighest': T('n', pick(90, 22)),
        'onSurface': T('n', pick(10, 90)),
        'onSurfaceVariant': T('nv', pick(30, 80)),
        'outline': T('nv', pick(50, 60)),
        'outlineVariant': T('nv', pick(80, 30)),
        'error': hexs(solve(25, 84, pick(40, 80))),
        'scrim': '#000000',
    }
    if mono:
        tones = {
            'primary': (pick(0, 100), 'p'), 'onPrimary': (pick(90, 10), 'p'),
            'primaryContainer': (pick(25, 85), 'p'), 'onPrimaryContainer': (pick(100, 0), 'p'),
            'secondary': (pick(40, 80), 's'), 'onSecondary': (pick(100, 10), 's'),
            'secondaryContainer': (pick(85, 30), 's'), 'onSecondaryContainer': (pick(10, 90), 's'),
            'tertiary': (pick(25, 90), 't'), 'onTertiary': (pick(90, 10), 't'),
            'tertiaryContainer': (pick(49, 60), 't'), 'onTertiaryContainer': (pick(100, 0), 't'),
        }
    else:
        tones = {}
        for name, k in (('primary', 'p'), ('secondary', 's'), ('tertiary', 't')):
            cap = name.capitalize()
            tones[name] = (pick(40, 80), k)
            tones['on' + cap] = (pick(100, 20), k)
            tones[name + 'Container'] = (pick(90, 30), k)
            tones['on' + cap + 'Container'] = (pick(10, 90), k)
    for name, (tone, k) in tones.items():
        out[name] = T(k, tone)
    return out


def themes() -> list[dict]:
    text = SRC.read_text(encoding='utf-8')
    rx = re.compile(r"ThemeChoice\('(\w+)', '([^']+)', Color\(0xFF([0-9A-Fa-f]{6})\)(, mono: true)?\)")
    res = []
    for tid, name, seed, mono in rx.findall(text):
        res.append({'id': tid, 'name': name, 'seed': '#' + seed.upper(),
                    'light': scheme(seed, bool(mono), False), 'dark': scheme(seed, bool(mono), True)})
    return res


def render() -> str:
    data = json.dumps(themes(), ensure_ascii=False, separators=(',', ':'))
    return ('/* Создано scripts/site/make_palette.py из lib/core/palette.dart. Вручную не править. */\n'
            f'window.JOURNAL_THEMES = {data};\n')


def main() -> int:
    text = render()
    if '--check' in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding='utf-8') != text:
            print('site/palette.js устарел: запустите python3 scripts/site/make_palette.py')
            return 1
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding='utf-8')
    print(f'Записано {OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
