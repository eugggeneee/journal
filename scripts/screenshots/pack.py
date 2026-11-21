"""Проверка полноты и сборка пар lossless WebP, включая собственные рамки в масштабе экрана."""
import hashlib
import json
import sys
from functools import lru_cache
from pathlib import Path
from PIL import Image, ImageDraw

SCENES = ('home-details date-picker schedule-menu grade-journal absence-calendar absence-journal home-compact schedule lesson mark absence-quick whole-day grades subject grade-form '
          'absences absence-form tasks task-form settings appearance theme-picker layout schedule-settings '
          'group bells-week bells-sat bells-short bell-editor absence-settings behavior data').split()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def names(ids):
    return sorted(SCENES+[f'home-{key}' for key in ids]+[f'welcome-{i}' for i in range(1,6)])


def complete(root, tag, expected):
    try:
        manifest = json.loads((root/'manifest.json').read_text())
        android = manifest['devices']['android']
        if (android['width'], android['height']) != (1080, 2340):
            return False
        if (manifest['tag'] != tag or set(manifest['devices']) != {'ios','android'}
                or manifest['scenes'] != expected):
            return False
        wanted = {f'{platform}/{mode}/{name}-{kind}.webp' for platform in manifest['devices']
                  for mode in ('light','dark') for name in manifest['scenes'] for kind in ('raw','framed')}
        return (wanted == set(manifest['files'])
                and all(digest(root/name) == manifest['files'][name] for name in wanted))
    except (FileNotFoundError, KeyError, ValueError):
        return False


@lru_cache(maxsize=4)
def chassis(width, height, platform):
    # Пропорции корпуса и ширины дисплея. Металл, стекло и вырез камеры — отдельные поверхности.
    ios = platform == 'ios'
    bezel = round(width * (.033 if ios else .029))
    gutter = round(width*.018)
    x, y = gutter+bezel, gutter+bezel
    frame = Image.new('RGBA', (width+2*x, height+2*y))
    d = ImageDraw.Draw(frame)
    left, top, right, bottom = gutter, gutter, frame.width-gutter-1, frame.height-gutter-1
    radius = round(width*(.162 if ios else .113))
    rail = max(6,round(width*.009))
    for i in range(rail):
        level = [66,123,180,151,111,85,69,89][min(7, i*8//rail)]
        d.rounded_rectangle((left+i,top+i,right-i,bottom-i), max(0,radius-i),
                            fill=(level,level+2,level+5))
    d.rounded_rectangle((left+rail,top+rail,right-rail,bottom-rail),radius-rail,fill='#101114')
    for edge, pos, length in ([('l',.18,.030),('l',.27,.062),('l',.348,.062),('r',.295,.091),('r',.59,.060)]
                              if ios else [('r',.22,.092),('r',.345,.058)]):
        t=round(height*pos)+top
        a,b = (left-max(3,rail//2),left+1) if edge=='l' else (right-1,right+max(3,rail//2))
        d.rounded_rectangle((a,t,b,t+round(height*length)),radius=2,fill='#50545b',outline='#35383c')
    for pos in (.115,.865):
        t=round(height*pos)+top
        for a in [left,right-rail+1]:
            d.rectangle((a,t,a+rail-1,t+max(2,rail//3)),fill='#535458')
    mask = Image.new('L',(width,height))
    ImageDraw.Draw(mask).rounded_rectangle((0,0,width-1,height-1),radius-bezel,fill=255)
    return frame,mask,(x,y)


def framed(image, platform):
    body, mask, (x,y) = chassis(*image.size, platform)
    canvas = body.copy()
    canvas.paste(image,(x,y),mask)
    w = image.width
    d = ImageDraw.Draw(canvas)
    cx=x+w//2
    if platform=='ios':
        rw,rh=round(w*.156),round(w*.047)
        t=y+round(w*.032)
        d.rounded_rectangle((cx-rw,t,cx+rw,t+2*rh),radius=rh,fill='#050506')
        lens = cx+round(rw*.64)
        r=max(2,round(w*.007))
        d.ellipse((lens-r,t+rh-r,lens+r,t+rh+r),fill='#121621')
    else:
        cy=y+round(w*.034)
        r=round(w*.012)
        d.ellipse((cx-r,cy-r,cx+r,cy+r),fill='#090a0d',outline='#22252a',width=2)
        d.ellipse((cx-r//3,cy-r//3,cx+r//3,cy+r//3),fill='#161c28')
    return canvas


def make(source, output, app, tag, commit):
    ids=json.loads((app/'assets/icons/icons.json').read_text())
    scenes=names(ids)
    manifest={'tag':tag, 'commit':commit, 'group':'0000', 'scenes':scenes, 'devices':{}, 'files':{}}
    for platform in ('ios','android'):
        folder=source/platform
        device=json.loads((folder/'device.json').read_text())
        manifest['devices'][platform]=device
        for mode in ('light','dark'):
            raw=folder/mode
            if {p.stem for p in raw.glob('*.png')}!=set(scenes):
                raise ValueError(f'Неполная съёмка {platform}/{mode}: {set(scenes) ^ {p.stem for p in raw.glob("*.png")}}')
            for name in scenes:
                with Image.open(raw/(name+'.png')) as png:
                    im=png.convert('RGB')
                if platform == 'android' and im.size != (1080, 2340):
                    raise ValueError(f'Unexpected Galaxy S26 frame size: {im.size}')
                if im.width < 1000 or im.height <= im.width or im.getextrema()[0][0]==im.getextrema()[0][1]:
                    raise ValueError(f'Некорректный кадр {raw/name}')
                device['width'],device['height']=im.size
                for kind,img in [('raw',im),('framed',framed(im,platform))]:
                    key=f'{platform}/{mode}/{name}-{kind}.webp'
                    dest=output/key
                    dest.parent.mkdir(parents=True,exist_ok=True)
                    img.save(dest, lossless=True,method=2)
                    manifest['files'][key]=digest(dest)
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert complete(output,tag,scenes)
    lines=['# Journal '+tag,'','Группа 0000. Все записи, аудитории и преподаватели вымышлены.','']
    for platform,device in manifest['devices'].items():
        lines.extend([f"## {device['model']}",'',f"{device['environment']} · {device['os']} · {device['width']} × {device['height']} px.",
                      '',f'[Светлая тема]({platform}/light/) · [Тёмная тема]({platform}/dark/)',''])
    lines.extend(['Файлы raw содержат экран устройства. В framed добавлена самостоятельно нарисованная рамка модели.',''])
    (output/'README.md').write_text('\n'.join(lines),encoding='utf-8')


if __name__=='__main__':
    if sys.argv[1]=='check':
        ids=json.loads(Path(sys.argv[4]).read_text())
        print('true' if complete(Path(sys.argv[2]),sys.argv[3],names(ids)) else 'false')
    else:
        make(*(Path(s) for s in sys.argv[2:5]),*sys.argv[5:7])
