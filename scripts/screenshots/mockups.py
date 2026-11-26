"""iPhone-корпуса и фирменные композиции из подлинных снимков приложения."""
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
def font(size, bold=False):
    family = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
    for name in (family, 'arialbd.ttf' if bold else 'arial.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    raise RuntimeError('Для фирменных макетов нужен шрифт с кириллицей')


def brand(canvas, icon, position, ink, badge, badge_ink, beta):
    x, y = position
    mark = ImageOps.contain(icon, (66, 66), Image.Resampling.LANCZOS)
    canvas.paste(mark, (x, y), mark)
    draw = ImageDraw.Draw(canvas)
    end = x + 84
    face = font(46, True)
    draw.text((end, y + 32), 'Journal', font=face, fill=ink, anchor='lm')
    if beta:
        left = round(end + draw.textlength('Journal', font=face)) + 20
        draw.rounded_rectangle((left, y + 8, left + 108, y + 58), radius=25, fill=badge)
        draw.text((left + 54, y + 31), 'бета', font=font(30, True), fill=badge_ink, anchor='mm')


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


def posters(pack, logo, channel):
    (pack / 'mockups').mkdir(exist_ok=True)
    with Image.open(logo) as source:
        icon = source.convert('RGBA')
    sizes = {'overview': (1800, 1200), 'day': (1600, 1000),
             'schedule': (1200, 1500), 'journal': (1600, 1360)}
    for mode in FINISHES:
        if mode == 'light':
            paper, ink, accent, field = '#f4f4ff', '#202446', '#3645a0', '#dce1ff'
        else:
            paper, ink, accent, field = '#141623', '#f0efff', '#c2caff', '#292f50'
        for name, size in sizes.items():
            canvas = Image.new('RGB', size, paper)
            draw = ImageDraw.Draw(canvas)
            width, height = size
            margin = round(width * .048)
            def device(scene, center, h):
                phone(canvas, pack, mode + '/' + scene, mode, center, h)
            if name == 'overview':
                draw.rounded_rectangle((margin, 349, width-margin, 1151), radius=90, fill=field)
                device('schedule', (470, 747), 663)
                device('grades', (1330, 747), 663)
                device('home-default', (900, 731), 834)
                title, title_pos, scale = 'Дневник студента МГТЭК', (margin, 166), 94
            elif name == 'day':
                draw.ellipse((750, -215, 2020, 1215), fill=field)
                device('home-default', (1150, 500), 880)
                draw.multiline_text((margin, 326), 'Ход\nдня', font=font(143, True), fill=ink, spacing=-15)
                title = None
            elif name == 'schedule':
                draw.rounded_rectangle((margin, 320, width-margin, 1445), radius=80, fill=field)
                device('schedule', (600, 880), 1130)
                title, title_pos, scale = 'Расписание', (margin, 164), 100
            else:
                draw.rounded_rectangle((margin, 314, width-margin, 1294), radius=84, fill=field)
                device('grades', (547, 802), 916)
                device('absences', (1053, 802), 916)
                title, title_pos, scale = 'Отметки и пропуски', (margin, 158), 96
            brand(canvas, icon, (margin, 62), ink, accent, paper, channel == 'beta')
            if title:
                draw.text(title_pos, title, font=font(scale, True), fill=ink)
            canvas.save(pack / poster_path(name, mode), quality=94, method=4)
