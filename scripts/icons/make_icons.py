#!/usr/bin/env python3
"""Рисует значок приложения (колокольчик на «тарелке») под каждую тему.

Запуск (нужны Pillow и numpy):  python3 scripts/icons/make_icons.py

Рисунок строится в сетке 108 x 108. «Тарелки» заданы кодом, колокольчик берётся из маски
scripts/icons/bell.png (белое на чёрном: 255 — колокольчик), одной на все темы.
Результат:
  assets/icon/icon.png, icon_ios.png    исходники для flutter_launcher_icons (тема «default»)
  assets/icons/<id>/ios.png             1024 x 1024, квадрат без прозрачности, светлый вариант iOS
  assets/icons/<id>/ios_dark.png        iOS 18+: тёмный вариант (глубже фон, тот же колокольчик)
  assets/icons/<id>/ios_tinted.png      iOS 18+: оттенки серого под тонировку системой
  assets/icons/<id>/fg.png, bg.png      432 x 432, слои адаптивного значка Android
  assets/icons/<id>/legacy.png          144 x 144, скруглённый значок для Android до 8.0
  assets/icons/layer_mono.png           одноцветный слой для «тематических значков» Android 13+
  assets/icons/preview/<id>.png         превью для экрана «Оформление»
  assets/icons/bell.png                 колокольчик без фона для экрана приветствия (белый, прозрачный)
  assets/icons/icons.json               список id тем

Адаптивный значок Android рисуется на холсте 108 dp, но лаунчер показывает центральные 72 dp
(остальное срезает маска). Поэтому композиция целиком масштабируется в эту область, а фон за её
пределами однотонный: на Android значок выглядит так же, как на iPhone, и не «увеличивается».
Колокольчик лежит внутри безопасной зоны 66 dp, поэтому не обрезается ни круглой, ни квадратной маской.
"""
import colorsys
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'assets', 'icon')
OUT = os.path.join(ROOT, 'assets', 'icons')
BELL = os.path.join(ROOT, 'scripts', 'icons', 'bell.png')

# id темы → оттенок (градусы). Совпадает с палитрой в lib/core/palette.dart (Material, оттенок 500).
HUES = {
    'red': 4, 'pink': 340, 'purple': 291, 'deepPurple': 262, 'indigo': 231,
    'blue': 207, 'lightBlue': 199, 'cyan': 187, 'teal': 174, 'green': 122,
    'lightGreen': 88, 'lime': 66, 'yellow': 54, 'amber': 45, 'orange': 36,
    'deepOrange': 14, 'brown': 16, 'blueGrey': 200,
}

GRID = 108.0
CANVAS = 432            # адаптивный слой Android: 108 dp * 4
VISIBLE = 288           # видимая область 72 dp
OFFSET = (CANVAS - VISIBLE) // 2
CORNER = 23.6 / GRID    # скругление плитки (доля стороны)
SS = 3                  # суперсэмплинг при отрисовке
BELL_H = 60.0           # высота колокольчика в сетке 108 (вместе с ушком и язычком)
BELL_CY = 54.0          # вертикальный центр колокольчика в сетке


# ───────────────────────── цвета ─────────────────────────

def hls(h, l, s):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, l, s)
    return np.array([round(r * 255), round(g * 255), round(b * 255)], dtype=np.float64)


def palette(icon_id):
    """Три тона фона (основа, внешняя и внутренняя «тарелка») и цвет колокольчика."""
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


def dark_variant(stops, cap):
    """iOS 18+, тёмный вариант: фон глубже, колокольчик тот же."""
    return [stops[0] * .62, stops[1] * .78, stops[2] * .86], cap


def tinted_variant():
    """iOS 18+, вариант под тонировку: оттенки серого на почти чёрном фоне."""
    g = lambda v: np.array([v, v, v], dtype=np.float64)
    return [g(12), g(34), g(54)], g(238)


# ───────────────────────── геометрия (сетка 108) ─────────────────────────

def lobe(cx, cy, r, n, amp, rot=0.0, steps=240):
    """Волнистый круг («печенье» Material 3 Expressive)."""
    pts = []
    for i in range(steps):
        a = i / steps * math.tau
        k = r + amp * math.cos(n * a)
        t = a + math.radians(rot)
        pts.append((cx + k * math.cos(t), cy + k * math.sin(t)))
    return pts


def load_bell():
    """Маска колокольчика (0…1). Лёгкое сглаживание убирает мелкие зазубрины исходной картинки."""
    src = Image.open(BELL).convert('L')
    sigma = 2.2
    blurred = np.asarray(src.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float64) / 255.0
    a = np.clip((blurred - 0.5) * 2.2 * sigma + 0.5, 0, 1)
    return Image.fromarray((a * 255 + .5).astype(np.uint8), 'L')


def bell_layer(fr, src):
    """Колокольчик нужного размера на холсте кадра: центр по горизонтали и BELL_CY по вертикали."""
    h = BELL_H * fr.k
    w = src.width * h / src.height
    big = src.resize((max(1, round(w)), max(1, round(h))), Image.LANCZOS)
    canvas = Image.new('L', (fr.px, fr.px), 0)
    cx = fr.ox + GRID / 2 * fr.k
    cy = fr.oy + BELL_CY * fr.k
    canvas.paste(big, (round(cx - big.width / 2), round(cy - big.height / 2)))
    return np.asarray(canvas, dtype=np.float64) / 255.0


# ───────────────────────── растеризация ─────────────────────────

class Frame:
    """Холст px x px, на котором сетка 108 занимает квадрат `size` px со смещением (ox, oy)."""

    def __init__(self, px, size, ox=0.0, oy=0.0):
        self.px = px
        self.k = size / GRID
        self.ox = ox
        self.oy = oy

    def pt(self, p):
        return ((self.ox + p[0] * self.k) * SS, (self.oy + p[1] * self.k) * SS)

    def new(self):
        return Image.new('L', (self.px * SS, self.px * SS), 0)

    def poly(self, d, pts):
        d.polygon([self.pt(p) for p in pts], fill=255)

    def finish(self, img):
        """Сжимает суперсэмплированную маску до px."""
        return np.asarray(img.resize((self.px, self.px), Image.BOX), dtype=np.float64) / 255.0


def masks(fr, bell_src):
    """Покрытие трёх слоёв: внешняя «тарелка», внутренняя «тарелка», колокольчик."""
    outer, inner = fr.new(), fr.new()
    fr.poly(ImageDraw.Draw(outer), lobe(54, 54, 46, 12, 3.0))
    fr.poly(ImageDraw.Draw(inner), lobe(54, 54, 37, 9, 2.5))
    return fr.finish(outer), fr.finish(inner), bell_layer(fr, bell_src)


def compose(stops, cap, m):
    outer, inner, bell = m
    h, w = outer.shape
    img = np.zeros((h, w, 3))
    img[:] = stops[0]
    for layer, color in ((outer, stops[1]), (inner, stops[2]), (bell, cap)):
        img = img * (1 - layer[..., None]) + color[None, None, :] * layer[..., None]
    return img


def to_img(arr, mode='RGB'):
    return Image.fromarray(np.clip(arr + .5, 0, 255).astype(np.uint8), mode)


def rounded_alpha(px):
    big = Image.new('L', (px * SS, px * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, px * SS - 1, px * SS - 1), radius=px * SS * CORNER, fill=255)
    return big.resize((px, px), Image.LANCZOS)


def rounded(img, px):
    out = img.resize((px, px), Image.LANCZOS).convert('RGBA')
    out.putalpha(rounded_alpha(px))
    return out


# ───────────────────────── сборка ─────────────────────────

def build(icon_id, ios_masks, android_masks):
    stops, cap = palette(icon_id)
    ios = to_img(compose(stops, cap, ios_masks))
    d_stops, d_cap = dark_variant(stops, cap)
    t_stops, t_cap = tinted_variant()
    ios_dark = to_img(compose(d_stops, d_cap, ios_masks))
    ios_tinted = to_img(compose(t_stops, t_cap, ios_masks))

    # адаптивные слои: фон и колокольчик отдельно, композиция внутри видимых 72 dp
    outer, inner, bell = android_masks
    bg = np.zeros((CANVAS, CANVAS, 3))
    bg[:] = stops[0]
    for layer, color in ((outer, stops[1]), (inner, stops[2])):
        bg = bg * (1 - layer[..., None]) + color[None, None, :] * layer[..., None]
    fg = np.zeros((CANVAS, CANVAS, 4))
    fg[..., :3] = cap
    fg[..., 3] = bell * 255
    return ios, ios_dark, ios_tinted, to_img(bg), to_img(fg, 'RGBA'), bell


def main():
    bell_src = load_bell()
    ios_masks = masks(Frame(1024, 1024), bell_src)
    android_masks = masks(Frame(CANVAS, VISIBLE, OFFSET, OFFSET), bell_src)

    ids = ['default', 'mono'] + list(HUES)
    os.makedirs(os.path.join(OUT, 'preview'), exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    bell_layer = None
    for icon_id in ids:
        ios, ios_dark, ios_tinted, bg, fg, bell = build(icon_id, ios_masks, android_masks)
        bell_layer = bell
        d = os.path.join(OUT, icon_id)
        os.makedirs(d, exist_ok=True)
        ios.save(os.path.join(d, 'ios.png'), optimize=True)
        ios_dark.save(os.path.join(d, 'ios_dark.png'), optimize=True)
        ios_tinted.save(os.path.join(d, 'ios_tinted.png'), optimize=True)
        bg.save(os.path.join(d, 'bg.png'), optimize=True)
        fg.save(os.path.join(d, 'fg.png'), optimize=True)
        rounded(ios, 144).save(os.path.join(d, 'legacy.png'), optimize=True)
        rounded(ios, 160).save(os.path.join(OUT, 'preview', f'{icon_id}.png'), optimize=True)
        if icon_id == 'default':
            rounded(ios, 1024).save(os.path.join(SRC, 'icon.png'), optimize=True)
            ios.save(os.path.join(SRC, 'icon_ios.png'), optimize=True)
        print('ok', icon_id)
    # одноцветный слой для «тематических значков» Android 13+ (общий для всех тем)
    mono = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    mono.putalpha(Image.fromarray((bell_layer * 255 + .5).astype(np.uint8), 'L'))
    mono.save(os.path.join(OUT, 'layer_mono.png'), optimize=True)
    # колокольчик без фона для экрана приветствия: белый, форма в альфа-канале, окрашивается в коде
    crop = bell_src.crop(bell_src.getbbox())
    side = 512
    h = side
    w = round(crop.width * h / crop.height)
    glyph = Image.new('RGBA', (w, h), (255, 255, 255, 0))
    glyph.putalpha(crop.resize((w, h), Image.LANCZOS))
    glyph.save(os.path.join(OUT, 'bell.png'), optimize=True)
    with open(os.path.join(OUT, 'icons.json'), 'w', encoding='utf-8') as f:
        json.dump(ids, f)
        f.write('\n')


if __name__ == '__main__':
    main()
