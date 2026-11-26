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


@lru_cache(maxsize=12)
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


def ripple(draw, center, radius, amplitude, petals, fill):
    points = []
    for step in range(720):
        theta = math.tau * step / 720
        r = radius + amplitude * math.cos(theta * petals)
        points.append((center[0] + r * math.cos(theta), center[1] + r * math.sin(theta)))
    draw.polygon(points, fill=fill)


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
            if name == 'overview':
                draw.rounded_rectangle((728, 147, 1930, 1100), radius=330, fill=field)
                line(76, 337, 'Дневник', 153)
                line(82, 506, 'студента', 130, secondary, 'regular')
                line(76, 678, 'МГТЭК', 145, accent)
                device('schedule', (945, 688), 662, 4)
                device('grades', (1544, 592), 662, -4)
                device('home-default', (1242, 610), 910)
            elif name == 'day':
                ripple(draw, (1252, 515), 509, 26, 8, field)
                line(65, 275, 'Ход', 257)
                line(176, 517, 'дня', 240, accent, 'bolditalic')
                device('home-default', (1150, 503), 875, -3)
            elif name == 'schedule':
                # Three quiet blocks follow the same cadence as lessons in the timetable.
                for i, (left, right, color) in enumerate([
                        (-130, 905, quiet), (142, 1245, field), (-110, 915, quiet)]):
                    top = 462 + 282 * i
                    draw.rounded_rectangle((left, top, right, top + 236), radius=118, fill=color)
                line(61, 182, 'Расписание', 170)
                device('schedule', (600, 918), 1044)
            else:
                draw.rounded_rectangle((665, 162, 1700, 1250), radius=268, fill=field)
                line(58, 451, 'Отметки', 133)
                line(72, 627, 'и пропуски', 102, secondary, 'regular')
                device('grades', (911, 592), 809, 2)
                device('absences', (1324, 837), 809, -2)
            brand(canvas, icon, (72, 67), ink, field, scheme['onPrimaryContainer'], channel == 'beta')
            canvas.save(pack / poster_path(name, mode), quality=94, method=4)
