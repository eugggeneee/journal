"""Создать варианты лаунчера из прозрачного экспорта assets/icons/bell.svg (1024 px)."""

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

root = Path('assets/icons')
master = Image.open(sys.argv[1]).convert('RGBA')
if master.size != (1024, 1024):
    raise ValueError('Нужен экспорт 1024 × 1024')
alpha = master.getchannel('A')
alpha = alpha.crop(alpha.getbbox())
resize = Image.Resampling.LANCZOS


def layer(canvas, height, rgb):
    mask = alpha.resize((round(height * alpha.width / alpha.height), height), resize)
    ink = Image.new('RGBA', mask.size, rgb)
    ink.putalpha(mask)
    result = Image.new('RGBA', (canvas, canvas))
    result.paste(ink, ((canvas - ink.width) // 2, (canvas - ink.height) // 2))
    return result


def blend(a, b, fraction):
    return tuple(round(x + (y - x) * fraction) for x, y in zip(a, b))


layer(624, 624, 'white').save(root / 'bell.png')
drawable = root / 'android/drawable-nodpi'
layer(432, 176, 'white').save(drawable / 'ic_mono_shared.png')
palette = dict(re.findall(r"ThemeChoice\('(\w+)', '[^']+', Color\(0xFF([0-9A-F]{6})\)", Path('lib/core/palette.dart').read_text(encoding='utf-8')))
for key in json.loads((root / 'icons.json').read_text()):
    seed = bytes.fromhex(palette[key])
    bg = blend(seed, (255, 255, 255), .65)
    fg = blend(seed, (23, 25, 35), .72)
    if key == 'mono':
        fg = (60, 60, 60)
    ios = root / 'ios' / ('AppIcon.icon' if key == 'default' else f'Icon_{key}.icon')
    layer(1024, 624, fg).save(ios / 'Assets/bell.png')
    doc = json.loads((ios / 'icon.json').read_text())
    doc['fill'] = {'solid': 'srgb:' + ','.join(f'{c/255:.5f}' for c in bg) + ',1.00000'}
    doc['groups'] = [{'layers': [{'image-name': 'bell.png', 'name': 'bell', 'glass': False}],
                      'shadow': {'kind': 'none', 'opacity': 0}, 'translucency': {'enabled': False, 'value': 0}}]
    (ios / 'icon.json').write_text(json.dumps(doc, indent=2) + '\n', encoding='utf-8')
    suffix = re.sub(r'[A-Z]', lambda m: '_' + m[0].lower(), key)
    Image.new('RGB', (432, 432), bg).save(drawable / f'ic_bg_{suffix}.png')
    layer(432, 176, fg).save(drawable / f'ic_fg_{suffix}.png')
    picture = Image.new('RGBA', (1024, 1024), bg)
    picture.alpha_composite(layer(1024, 624, fg))
    name = 'ic_launcher' if key == 'default' else 'ic_launcher_' + suffix
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        for ending in ['', '_round']:
            mask = Image.new('L', picture.size)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=512 if ending else 228, fill=255)
            picture.putalpha(mask)
            picture.resize((size, size), resize).save(root / 'android' / ('mipmap-' + density) / (name + ending + '.png'))
