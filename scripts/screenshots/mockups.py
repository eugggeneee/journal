"""iPhone-корпуса и фирменные композиции из подлинных снимков приложения."""
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

FRAMES = Path(__file__).parent / 'frames'
FINISHES = ('light', 'dark')
POSTERS = ('day', 'schedule', 'journal')


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


def brand(canvas, icon, position, ink):
    x, y = position
    mark = ImageOps.contain(icon, (52, 52), Image.Resampling.LANCZOS)
    canvas.paste(mark, (x, y), mark)
    ImageDraw.Draw(canvas).text((x + 68, y + 5), 'Journal', font=font(36, True), fill=ink)


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


def posters(pack, logo):
    folder = pack / 'mockups'
    folder.mkdir()
    with Image.open(logo) as source:
        icon = source.convert('RGBA')

    day = Image.new('RGB', (1600, 1000), '#edefff')
    d = ImageDraw.Draw(day)
    d.ellipse((794, -360, 2100, 1110), fill='#ccd3ff')
    brand(day, icon, (86, 82), '#25305d')
    d.multiline_text((80, 330), 'Ход\nдня', font=font(145, True), fill='#1e2750', spacing=-12)
    d.text((88, 843), 'Расписание и дневник МГТЭК', font=font(30), fill='#4b547b')
    phone(day, pack, 'light/home-default', 'light', (1155, 500), 902)
    day.save(folder / 'day.webp', quality=94, method=4)

    schedule = Image.new('RGB', (1200, 1500), '#161a2b')
    d = ImageDraw.Draw(schedule)
    d.ellipse((-670, 520, 1150, 2180), fill='#252d50')
    brand(schedule, icon, (70, 65), '#e9ebff')
    d.text((62, 178), 'Расписание', font=font(109, True), fill='#d8ddff')
    phone(schedule, pack, 'dark/schedule', 'dark', (600, 872), 1148)
    schedule.save(folder / 'schedule.webp', quality=94, method=4)

    journal = Image.new('RGB', (1600, 1360), '#f9f7f3')
    d = ImageDraw.Draw(journal)
    d.rounded_rectangle((66, 331, 1534, 1290), radius=104, fill='#dce2f7')
    brand(journal, icon, (80, 63), '#24283b')
    d.text((74, 165), 'Оценки и пропуски', font=font(102, True), fill='#252b43')
    phone(journal, pack, 'light/grades', 'light', (532, 815), 905, 4)
    phone(journal, pack, 'dark/absences', 'dark', (1070, 815), 905, -4)
    journal.save(folder / 'journal.webp', quality=94, method=4)
