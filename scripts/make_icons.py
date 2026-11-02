#!/usr/bin/env python3
"""Генерирует значки приложения под каждую тему из исходников assets/icon/*.png.

Запуск (нужны Pillow и numpy):  python3 scripts/make_icons.py

Результат — assets/icons/<id>/ :
  ios.png      1024×1024, квадрат без прозрачности (iOS)
  fg.png       432×432, передний слой адаптивного значка Android
  bg.png       432×432, задний слой адаптивного значка Android
  legacy.png   144×144, скруглённый значок для Android до 8.0
и assets/icons/preview/<id>.png — превью для экрана «Оформление».
Значок «default» повторяет исходный, остальные перекрашены в оттенок темы.
"""
import colorsys
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'icon')
OUT = os.path.join(ROOT, 'assets', 'icons')

# id темы → оттенок (градусы). Совпадает с палитрой в lib/ui/theme.dart (Material, оттенок 500).
HUES = {
    'red': 4, 'pink': 340, 'purple': 291, 'deepPurple': 262, 'indigo': 231,
    'blue': 207, 'lightBlue': 199, 'cyan': 187, 'teal': 174, 'green': 122,
    'lightGreen': 88, 'lime': 66, 'yellow': 54, 'amber': 45, 'orange': 36,
    'deepOrange': 14, 'brown': 16, 'blueGrey': 200,
}
# Исходный значок: тёмный фон (23,30,50), круги (38,51,79) и (48,63,93), шапочка (190,195,255).
STOPS_R = [23, 38, 48]


def hls(h, l, s):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, l, s)
    return np.array([round(r * 255), round(g * 255), round(b * 255)], dtype=np.float64)


def palette(icon_id):
    """Три тона фона и цвет шапочки."""
    if icon_id == 'default':
        return [np.array(c, dtype=np.float64) for c in [(23, 30, 50), (38, 51, 79), (48, 63, 93)]], np.array([190, 195, 255.0])
    if icon_id == 'mono':
        return [hls(0, .09, 0), hls(0, .16, 0), hls(0, .21, 0)], hls(0, .92, 0)
    h = HUES[icon_id]
    # у коричневого и серо-синего пониженная насыщенность — как у самих тем
    k = {'brown': .55, 'blueGrey': .6}.get(icon_id, 1.0)
    # у жёлто-зелёных оттенков тёмные тона кажутся грязнее — слегка уменьшаем насыщенность
    warm = 0.8 if 40 <= h <= 100 else 1.0
    bg = [hls(h, .14, .40 * k * warm), hls(h, .22, .38 * k * warm), hls(h, .27, .35 * k * warm)]
    return bg, hls(h, .87, min(1.0, .95 * k + .05))


def recolor_bg(bg_src, stops):
    """Перекрашивает задний слой: R-канал исходника однозначно определяет положение между тремя тонами."""
    r = bg_src[..., 0].astype(np.float64)
    out = np.zeros(bg_src.shape[:2] + (3,))
    for ch in range(3):
        out[..., ch] = np.interp(r, STOPS_R, [s[ch] for s in stops])
    return out


def build(icon_id, bg_src, fg_alpha, round_alpha):
    stops, cap = palette(icon_id)
    bg = recolor_bg(bg_src, stops)
    a = fg_alpha[..., None]
    ios = bg * (1 - a) + cap[None, None, :] * a
    to_img = lambda arr, mode='RGB': Image.fromarray(np.clip(arr + .5, 0, 255).astype(np.uint8), mode)

    ios_img = to_img(ios)
    bg_img = to_img(bg)
    fg_arr = np.zeros(fg_alpha.shape + (4,))
    fg_arr[..., :3] = cap
    fg_arr[..., 3] = fg_alpha[..., ] * 255
    fg_img = to_img(fg_arr, 'RGBA')

    legacy = ios_img.convert('RGBA')
    legacy.putalpha(Image.fromarray((round_alpha * 255).astype(np.uint8), 'L'))
    return ios_img, bg_img, fg_img, legacy


def main():
    bg_src = np.array(Image.open(os.path.join(SRC, 'icon_bg.png')).convert('RGB'))
    fg_alpha = np.array(Image.open(os.path.join(SRC, 'icon_fg.png')).convert('RGBA'))[..., 3] / 255.0
    round_alpha = np.array(Image.open(os.path.join(SRC, 'icon.png')).convert('RGBA'))[..., 3] / 255.0

    ids = ['default', 'mono'] + list(HUES)
    os.makedirs(os.path.join(OUT, 'preview'), exist_ok=True)
    for icon_id in ids:
        ios, bg, fg, legacy = build(icon_id, bg_src, fg_alpha, round_alpha)
        d = os.path.join(OUT, icon_id)
        os.makedirs(d, exist_ok=True)
        ios.save(os.path.join(d, 'ios.png'), optimize=True)
        bg.resize((432, 432), Image.LANCZOS).save(os.path.join(d, 'bg.png'), optimize=True)
        fg.resize((432, 432), Image.LANCZOS).save(os.path.join(d, 'fg.png'), optimize=True)
        legacy.resize((144, 144), Image.LANCZOS).save(os.path.join(d, 'legacy.png'), optimize=True)
        legacy.resize((160, 160), Image.LANCZOS).save(os.path.join(OUT, 'preview', f'{icon_id}.png'), optimize=True)
        print('ok', icon_id)
    with open(os.path.join(OUT, 'icons.json'), 'w', encoding='utf-8') as f:
        json.dump(ids, f)


if __name__ == '__main__':
    main()
