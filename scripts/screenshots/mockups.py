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


def page_fan(draw, size, paper, field, edge):
    # Project a fan of leaves onto the cover. Their lines converge past the crop.
    w, h = size
    origin = (-w * .28, h * 1.27)
    previous = None
    for i in range(18):
        t = i / 17
        end = (w * 1.09, h * (1.62 - 1.52 * t))
        curve = []
        for j in range(101):
            u = j / 100
            bend = math.sin(math.pi * u)
            curve.append((origin[0] + (end[0] - origin[0]) * u,
                          origin[1] + (end[1] - origin[1]) * u - h * (.04 + .31*t) * bend))
        if previous is not None:
            draw.polygon(previous + curve[::-1], fill=(field if i % 4 else paper))
            draw.line(curve, fill=edge, width=3 if i % 4 == 0 else 1)
        previous = curve


def dial(draw, cx, cy, radius, scheme):
    # Rings and a swept arc read as the same clock at poster and thumbnail sizes.
    def circle(r):
        return (cx-r, cy-r, cx+r, cy+r)
    draw.ellipse(circle(radius), fill=scheme['primaryContainer'])
    draw.arc(circle(radius-30), 92, 263, fill=scheme['primary'], width=35)
    draw.arc(circle(radius-89), 118, 260, fill=scheme['surface'], width=4)
    for minute in range(60):
        angle = math.radians(minute*6 - 90)
        major = minute % 5 == 0
        ends = [(cx+math.cos(angle)*r, cy+math.sin(angle)*r)
                for r in (radius-101, radius-(137 if major else 115))]
        draw.line(ends, fill=scheme['onPrimaryContainer'], width=7 if major else 3)


def posters(pack, logo, channel):
    (pack / 'mockups').mkdir(exist_ok=True)
    sizes = {'overview': (1800, 1200), 'day': (1600, 1000),
             'schedule': (1200, 1500), 'journal': (1600, 1360)}
    palettes = Path(__file__).resolve().parents[1] / 'icons/artwork_palettes.json'
    standard = json.loads(palettes.read_text(encoding='utf-8'))['default']
    for mode in FINISHES:
        alternate = logo.with_name('logo-dark.png')
        with Image.open(alternate if mode == 'dark' and alternate.is_file() else logo) as source:
            icon = source.convert('RGBA')
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
                page_fan(draw, size, scheme['surfaceContainer'], mid, scheme['outline'])
                # The masthead has its own clear margin above the centre phone.
                draw.rounded_rectangle((-144, -186, 1260, 395), radius=174, fill=paper)
                line(69, 170, 'Дневник', 163)
                line(796, 198, 'студента', 102, secondary, 'regular')
                draw.rounded_rectangle((1285, 159, 1732, 318), radius=80, fill=accent)
                line(1345, 188, 'МГТЭК', 102, scheme['onPrimary'])
                device('schedule', (448, 768), 712, 9)
                device('grades', (1366, 744), 714, -9)
                device('home-default', (906, 759), 824)
            elif name == 'day':
                dial(draw, 1210, 560, 595, scheme)
                line(56, 229, 'Ход', 300)
                line(143, 540, 'дня', 254, accent, 'bolditalic')
                device('home-default', (1205, 508), 866, -5)
            elif name == 'schedule':
                # An accordion fold of timetable columns crosses the full bleed.
                draw.polygon([(0, 720), (1200, 347), (1200, 1500), (0, 1500)], fill=mid)
                for i in range(-1, 6):
                    x = i * 264
                    top = 758 - x * .31
                    draw.polygon([(x, top), (x+180, top-102), (x+224, 1500), (x+52, 1500)],
                                 fill=strong)
                    draw.line([(x+180, top-102), (x+224, 1500)], fill=accent, width=4)
                line(62, 181, 'Расписание', 166)
                device('schedule', (605, 916), 1036, -5)
            else:
                # A spine and two curved page edges, drawn from the same mirrored profile.
                cy = 740
                for side in (-1, 1):
                    for inset, fill in [(0, quiet), (16, paper), (26, mid), (40, scheme['secondaryContainer'])]:
                        left, right = 0, 722-inset
                        curve = [(800 + side*x, 343 + 34*(1-x/722)**3 - 31*math.sin(math.pi*x/722) + inset*.12)
                                 for x in range(left, right, 4)]
                        bottom = [(x, 2*cy + 160-y-inset*.55) for x, y in reversed(curve)]
                        draw.polygon(curve+bottom, fill=fill)
                draw.line([(800, 382),(800, 1225)], fill=scheme['outline'], width=4)
                line(66, 168, 'Отметки', 145)
                line(759, 203, 'и пропуски', 111, accent, 'regular')
                device('grades', (443, 809), 810, 3)
                device('absences', (1151, 809), 810, -3)
            brand(canvas, icon, (72, 67), ink, field, scheme['onPrimaryContainer'], channel == 'beta')
            canvas.save(pack / poster_path(name, mode), quality=94, method=4)
