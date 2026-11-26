"""iPhone-корпуса и фирменные композиции из подлинных снимков приложения."""
import json
import math
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
def font(size, weight='black'):
    root = Path(os.environ['JOURNAL_FONT_DIR'])
    return ImageFont.truetype(str(root / f'roboto-{weight}.ttf'), size)


def brand(canvas, icon, position, ink, badge, badge_ink, beta):
    x, y = position
    mark = ImageOps.contain(icon, (66, 66), Image.Resampling.LANCZOS)
    canvas.paste(mark, (x, y), mark)
    draw = ImageDraw.Draw(canvas)
    end = x + 84
    face = font(46, 'bold')
    draw.text((end, y + 32), 'Journal', font=face, fill=ink, anchor='lm')
    if beta:
        left = round(end + draw.textlength('Journal', font=face)) + 20
        draw.rounded_rectangle((left, y + 8, left + 108, y + 58), radius=25, fill=badge)
        draw.text((left + 54, y + 31), 'бета', font=font(30, 'medium'), fill=badge_ink, anchor='mm')


def phone(canvas, pack, key, finish, center, height, angle=0):
    with Image.open(pack / 'ios' / (key + '-framed-' + finish + '.webp')) as source:
        layer = source.convert('RGBA')
    layer.thumbnail((canvas.width, height), Image.Resampling.LANCZOS)
    if angle:
        layer = layer.rotate(angle, Image.Resampling.BICUBIC, expand=True)
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


def sweep(draw, size, baseline, rise, fill):
    """A broad ascending curve, shared by the three phones on the cover."""
    width, height = size
    points = []
    for x in range(0, width + 1, 4):
        phase = math.pi * x / width
        y = baseline - rise * (.5 - .5 * math.cos(phase))
        points.append((x, round(y)))
    draw.polygon([*points, (width, height), (0, height)], fill=fill)


def posters(pack, logo, channel):
    (pack / 'mockups').mkdir(exist_ok=True)
    with Image.open(logo) as source:
        icon = source.convert('RGBA')
    sizes = {'overview': (1800, 1200), 'day': (1600, 1000),
             'schedule': (1200, 1500), 'journal': (1600, 1360)}
    palettes = Path(__file__).resolve().parents[1] / 'icons/artwork_palettes.json'
    standard = json.loads(palettes.read_text(encoding='utf-8'))['default']
    for mode in FINISHES:
        scheme = standard[mode]
        paper, ink = scheme['surface'], scheme['onSurface']
        accent, field = scheme['primary'], scheme['primaryContainer']
        quiet, secondary = scheme['surfaceContainerHighest'], scheme['onSurfaceVariant']
        for name, size in sizes.items():
            canvas = Image.new('RGB', size, paper)
            draw = ImageDraw.Draw(canvas)
            def device(scene, center, h, angle=0):
                phone(canvas, pack, mode + '/' + scene, mode, center, h, angle)
            def line(x, y, text, size, color=ink, weight='black'):
                draw.text((x, y), text, font=font(size, weight), fill=color, anchor='lt')
            strong = scheme['onPrimaryContainer'] if mode == 'light' else field
            mid = scheme['primaryContainer'] if mode == 'light' else scheme['secondaryContainer']
            if name == 'overview':
                # A continuous, rising horizon links the schedule, live day and journal.
                sweep(draw, size, 873, 400, mid)
                sweep(draw, size, 1033, 431, strong)
                line(73, 183, 'Дневник студента', 123)
                line(1260, 202, 'МГТЭК', 113, accent)
                device('schedule', (449, 803), 665, 7)
                device('grades', (1364, 729), 716, -7)
                device('home-default', (899, 760), 826)
            elif name == 'day':
                # Minute ticks belong to the countdown and stay behind the phone.
                cx, cy, radius = 1262, 590, 585
                draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=mid)
                draw.pieslice((cx-radius+68, cy-radius+68, cx+radius-68, cy+radius-68),
                              106, 278, fill=strong)
                for angle in range(117, 270, 12):
                    rad = math.radians(angle)
                    inside = radius - (58 if (angle - 117) % 36 == 0 else 35)
                    pts = [(cx + r * math.cos(rad), cy + r * math.sin(rad)) for r in (inside, radius-18)]
                    draw.line(pts, fill=scheme['onPrimaryContainer'], width=6)
                line(64, 241, 'Ход', 273)
                line(173, 534, 'дня', 239, accent, 'bolditalic')
                device('home-default', (1159, 506), 872, -4)
            elif name == 'schedule':
                # Broad folded bands cross the page behind the vertical timetable.
                for top, color in ((646, quiet), (811, mid), (975, strong)):
                    draw.polygon([(0, top), (1200, top-330), (1200, 1500), (0, 1500)], fill=color)
                line(63, 196, 'Расписание', 165)
                device('schedule', (629, 908), 1024, -4)
            else:
                # Two adjoining leaves of a diary, with a continuous centre seam.
                draw.rounded_rectangle((62, 343, 1538, 1304), radius=132, fill=mid)
                draw.rounded_rectangle((800, 343, 1538, 1304), radius=132, fill=strong)
                draw.rectangle((800, 475, 920, 1304), fill=strong)
                draw.ellipse((698, 1177, 898, 1377), fill=paper)
                line(63, 175, 'Отметки', 142)
                line(732, 198, 'и пропуски', 115, accent, 'regular')
                device('grades', (465, 820), 827, 3)
                device('absences', (1134, 819), 827, -3)
            brand(canvas, icon, (72, 67), ink, field, scheme['onPrimaryContainer'], channel == 'beta')
            canvas.save(pack / poster_path(name, mode), quality=94, method=4)
