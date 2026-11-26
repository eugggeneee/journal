"""iPhone-корпуса и фирменные композиции из подлинных снимков приложения."""
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


def wave(draw, start, end, y, height, period, stroke, color):
    points = [(x, y + height * math.sin((x - start) * math.tau / period))
              for x in range(start, end + 1, 2)]
    draw.line(points, fill=color, width=stroke, joint='curve')


def posters(pack, logo, channel):
    (pack / 'mockups').mkdir(exist_ok=True)
    with Image.open(logo) as source:
        icon = source.convert('RGBA')
    sizes = {'overview': (1800, 1200), 'day': (1600, 1000),
             'schedule': (1200, 1500), 'journal': (1600, 1360)}
    for mode in FINISHES:
        dark = mode == 'dark'
        paper = '#211334' if dark else '#f9edff'
        ink = '#fff0fa' if dark else '#311043'
        purple = '#794bba' if dark else '#bb99ed'
        deep = '#3d2359' if dark else '#e6cbf5'
        mint = '#87dbc5' if dark else '#a4edce'
        coral = '#ef909c' if dark else '#ffacac'
        lime = '#cde879' if dark else '#d8f58f'
        for name, size in sizes.items():
            canvas = Image.new('RGB', size, paper)
            draw = ImageDraw.Draw(canvas)
            def device(scene, center, h, angle=0):
                phone(canvas, pack, mode + '/' + scene, mode, center, h, angle)
            def line(x, y, text, size, color=ink, weight='black'):
                draw.text((x, y), text, font=font(size, weight), fill=color, anchor='lt')
            if name == 'overview':
                # A staggered group of devices follows the same rising rhythm as a ring.
                draw.rounded_rectangle((746, -180, 1910, 1370), radius=330, fill=deep)
                ripple(draw, (1404, 585), 571, 36, 9, purple)
                for offset in (0, 96, 192):
                    draw.arc((964 + offset, -522 + offset, 2098 - offset, 612 - offset),
                             55, 166, fill=mint, width=24)
                for offset in (0, 63, 126):
                    wave(draw, -34, 640, 1070 + offset, 42, 380, 26, purple)
                line(64, 281, 'Дневник', 156)
                line(82, 448, 'студента', 137, weight='regular')
                draw.rounded_rectangle((68, 611, 670, 835), radius=112, fill=lime)
                line(130, 650, 'МГТЭК', 145, '#291438')
                device('schedule', (949, 752), 670, 5)
                device('grades', (1578, 615), 690, -5)
                device('home-default', (1276, 643), 952)
            elif name == 'day':
                draw.ellipse((619, -366, 1910, 1320), fill=deep)
                ripple(draw, (1242, 526), 531, 48, 12, mint)
                ripple(draw, (1242, 526), 441, 42, 12, purple)
                for x, y, r in [(532, 354, 45), (589, 294, 29), (630, 249, 17)]:
                    draw.ellipse((x-r, y-r, x+r, y+r), fill=coral)
                line(62, 241, 'Ход', 271)
                line(184, 509, 'дня', 257, weight='bolditalic')
                wave(draw, -50, 689, 898, 35, 265, 29, purple)
                device('home-default', (1174, 512), 909, -4)
            elif name == 'schedule':
                # Offset slots echo the time grid shown in the screenshot.
                draw.rounded_rectangle((-145, 252, 1351, 1665), radius=178, fill=deep)
                for i in range(5):
                    y = 440 + i * 213
                    start = -150 if i % 2 == 0 else 38
                    draw.rounded_rectangle((start, y, 1160 + start, y + 142),
                                           radius=71, fill=(purple, mint, coral, purple, lime)[i])
                draw.rounded_rectangle((38, 157, 1156, 368), radius=103, fill=lime)
                line(89, 188, 'Расписание', 168, '#291438')
                device('schedule', (600, 932), 1035, -3)
            else:
                draw.rounded_rectangle((658, -125, 1800, 1590), radius=255, fill=deep)
                ripple(draw, (1177, 850), 570, 33, 8, purple)
                draw.ellipse((1021, -301, 1740, 417), fill=coral)
                draw.ellipse((1125, -193, 1636, 309), fill=deep)
                line(58, 307, 'Отметки', 138)
                draw.rounded_rectangle((63, 489, 198, 629), radius=68, fill=mint)
                line(97, 516, 'и', 100, '#291438')
                line(68, 669, 'пропуски', 132, weight='regular')
                for y in (1036, 1116, 1196):
                    wave(draw, -15, 588, y, 38, 330, 24, purple)
                device('grades', (910, 602), 824, 3)
                device('absences', (1320, 890), 824, -3)
            brand(canvas, icon, (70, 62), ink, mint, '#291438', channel == 'beta')
            canvas.save(pack / poster_path(name, mode), quality=94, method=4)
