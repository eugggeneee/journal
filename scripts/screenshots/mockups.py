"""iPhone-корпуса и фирменные композиции из подлинных снимков приложения."""
import json
import os
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

FRAMES = Path(__file__).parent / 'frames'
FINISHES = ('light', 'dark')
POSTERS = ('overview', 'day', 'schedule', 'journal')


@lru_cache(maxsize=4)
def frame_layers(finish, width, height):
    with Image.open(FRAMES / f'iphone-{finish}.png') as source:
        shell = source.convert('RGBA')
    openings = shell.getchannel('A').point(lambda a: 255 if a < 128 else 0)
    ImageDraw.floodfill(openings, (shell.width // 2, shell.height // 2), 128)
    screen = openings.point(lambda value: 255 if value == 128 else 0)
    left, top, right, bottom = screen.getbbox()
    sx, sy = width / (right - left), height / (bottom - top)
    size = (round(shell.width * sx), round(shell.height * sy))
    screen = screen.filter(ImageFilter.MaxFilter(5))
    return (shell.resize(size, Image.Resampling.LANCZOS),
            screen.resize(size, Image.Resampling.LANCZOS),
            (round(left * sx), round(top * sy)))


def framed(raw, finish):
    shell, mask, origin = frame_layers(finish, *raw.size)
    display = Image.new('RGBA', shell.size)
    display.paste(raw, origin)
    # The mask follows the display glass and the camera cutout.
    display.putalpha(mask)
    return Image.alpha_composite(display, shell)


@lru_cache(maxsize=48)
def font(size, weight='bold'):
    root = Path(os.environ['JOURNAL_FONT_DIR'])
    return ImageFont.truetype(str(root / f'roboto-{weight}.ttf'), size)


def brand(canvas, icon, position, ink, badge, badge_ink, beta):
    x, y = position
    # Keep the wordmark and channel legible at the same gallery preview width.
    unit = canvas.width / 360
    mark_size = round(15 * unit)
    mark = ImageOps.contain(icon, (mark_size, mark_size), Image.Resampling.LANCZOS)
    canvas.paste(mark, (x, y), mark)
    draw = ImageDraw.Draw(canvas)
    start = x + mark_size + round(4 * unit)
    middle = y + mark_size / 2
    face = font(round(11 * unit), 'bold')
    # Centre the visible lettering, including the ascending stroke in «бета».
    def label(left, text, face, color):
        _, top, _, bottom = face.getbbox(text, anchor='ls')
        draw.text((left, round(middle - (top + bottom) / 2)), text,
                  font=face, fill=color, anchor='ls')
    label(start, 'Journal', face, ink)
    if beta:
        left = round(start + face.getlength('Journal') + 5 * unit)
        caption = font(round(8 * unit), 'medium')
        pad, radius = round(4 * unit), round(6.5 * unit)
        right = left + pad * 2 + round(caption.getlength('бета'))
        draw.rounded_rectangle((left, middle-radius, right, middle+radius), radius, fill=badge)
        label(left + pad, 'бета', caption, badge_ink)


def headline(draw, origin, text, size, ink):
    face = font(size, 'black')
    x, cap_top = origin
    baseline = cap_top - face.getbbox('Н', anchor='ls')[1]
    # Preserve pair kerning while gently tightening large Cyrillic display type.
    for line in text.splitlines():
        for i, char in enumerate(line):
            end = face.getlength(line[:i + 1])
            left = x + end - face.getlength(char) - i * size * .025
            draw.text((round(left), baseline), char, font=face, fill=ink, anchor='ls')
        baseline += round(.83 * size)


def phone(canvas, pack, key, finish, center, height):
    with Image.open(pack / 'ios' / (key + '-framed-' + finish + '.webp')) as source:
        layer = source.convert('RGBA')
    layer.thumbnail((canvas.width, height), Image.Resampling.LANCZOS)
    x, y = center[0] - layer.width // 2, center[1] - layer.height // 2
    shadow = Image.new('L', canvas.size)
    shadow.paste(layer.getchannel('A'), (x + 10, y + 18))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18)).point(lambda a: a // 4)
    canvas.paste((18, 20, 35), (0, 0, *canvas.size), shadow)
    canvas.paste(layer, (x, y), layer)


def poster_path(name, mode):
    # Keep the established public filename for the original appearance of each poster.
    original = 'dark' if name == 'schedule' else 'light'
    suffix = '' if mode == original else '-' + mode
    return f'mockups/{name}{suffix}.webp'


def shape(draw, start, curves, corners, fill):
    """Draw one closed silhouette from cubic Bézier segments."""
    points = [start]
    x0, y0 = start
    for x1, y1, x2, y2, x3, y3 in curves:
        for step in range(1, 65):
            t = step / 64
            u = 1 - t
            points.append((u**3*x0 + 3*u*u*t*x1 + 3*u*t*t*x2 + t**3*x3,
                           u**3*y0 + 3*u*u*t*y1 + 3*u*t*t*y2 + t**3*y3))
        x0, y0 = x3, y3
    draw.polygon(points + corners, fill=fill)


def posters(pack, logo, channel):
    (pack / 'mockups').mkdir(exist_ok=True)
    # Each composition shares a 16 px grid and a single upright headline.
    # Position fields as (x, y) centres to keep phone pairs optically balanced.
    layouts = {
        'overview': ((1800, 1200), 'Дневник студента МГТЭК', (96, 178), 136, [
            ('schedule', (464, 752), 704), ('home-default', (900, 752), 832),
            ('grades', (1336, 752), 704)]),
        'day': ((1600, 1000), 'Ход\nдня', (80, 256), 288, [
            ('home-default', (1136, 500), 832)]),
        'schedule': ((1200, 1500), 'Расписание', (64, 172), 188, [
            ('schedule', (600, 896), 1040)]),
        'journal': ((1600, 1360), 'Отметки и пропуски', (80, 174), 154, [
            ('grades', (532, 824), 896), ('absences', (1068, 824), 896)]),
    }
    palettes = Path(__file__).resolve().parents[1] / 'icons/artwork_palettes.json'
    standard = json.loads(palettes.read_text(encoding='utf-8'))['default']
    for mode in FINISHES:
        alternate = logo.with_name('logo-dark.png')
        with Image.open(alternate if mode == 'dark' and alternate.is_file() else logo) as source:
            icon = source.convert('RGBA')
        scheme = standard[mode]
        field, accent = scheme['primaryContainer'], scheme['primary']
        for name, (size, title, origin, font_size, devices) in layouts.items():
            canvas = Image.new('RGB', size, scheme['surface'])
            draw = ImageDraw.Draw(canvas)
            if name == 'overview':
                # Two sweeps cross behind the group and leave the masthead clear.
                shape(draw, (-16, 872), [
                    (368, 880, 432, 360, 982, 360), (1352, 360, 1560, 640, 1816, 496),
                ], [(1816, 1216), (-16, 1216)], field)
                shape(draw, (680, 1216), [
                    (1016, 1216, 1112, 1064, 1296, 1008), (1512, 944, 1680, 1000, 1816, 816),
                ], [(1816, 1216)], accent)
            elif name == 'day':
                # A large soft shoulder comes in from the right of the title.
                shape(draw, (1616, -16), [
                    (1400, -16, 1360, 144, 1152, 144), (856, 144, 752, 268, 752, 508),
                    (752, 816, 1104, 808, 1104, 1016), ], [(1616, 1016)], field)
                shape(draw, (1616, 464), [
                    (1536, 464, 1392, 536, 1392, 700), (1392, 848, 1536, 908, 1536, 1016),
                ], [(1616, 1016)], accent)
            elif name == 'schedule':
                # The broad crest and the cropped lower arc bracket the phone.
                shape(draw, (-16, 984), [
                    (272, 984, 320, 476, 672, 476), (888, 476, 1024, 604, 1216, 536),
                ], [(1216, 1516), (-16, 1516)], field)
                draw.ellipse((-768, 1032, 304, 2104), fill=accent)
            else:
                # A continuous two-lobed field holds both screens at the same height.
                shape(draw, (-16, 808), [
                    (184, 808, 184, 464, 472, 464), (664, 464, 696, 600, 840, 600),
                    (1024, 600, 1040, 472, 1328, 472), (1456, 472, 1552, 532, 1616, 576),
                ], [(1616, 1376), (-16, 1376)], field)
                shape(draw, (848, 1376), [
                    (944, 1360, 1072, 1312, 1184, 1232), (1320, 1136, 1424, 1072, 1616, 1072),
                ], [(1616, 1376)], accent)
            for scene, center, height in devices:
                phone(canvas, pack, f'{mode}/{scene}', mode, center, height)
            headline(draw, origin, title, font_size, scheme['onSurface'])
            brand(canvas, icon, (origin[0], 64), scheme['onSurface'], field,
                  scheme['onPrimaryContainer'], channel == 'beta')
            canvas.save(pack / poster_path(name, mode), quality=94, method=4)
