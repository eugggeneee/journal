"""Собрать страницы и два источника из метаданных GitHub и проверенных IPA."""
import hashlib
import json
import os
from concurrent.futures import ThreadPoolExecutor
import re
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image, ImageDraw, ImageFont, ImageOps
from altstore_source import BASE_URL, make_source

REPO = 'eugggeneee/journal'
TAG = re.compile(r'v(\d+)\.(\d+)\.(\d+)(?:-(beta|rc)\.(\d+))?')
VIEWS = [('light','home-default','Ход дня'), ('dark','schedule','Расписание'),
         ('light','grades','Оценки'), ('dark','absences','Пропуски'), ('light','tasks','Задания')]


def command(*argv):
    return subprocess.check_output(argv)


def key(release):
    m = TAG.fullmatch(release['tag_name'])
    return tuple(map(int, m.groups()[:3])) + ({'beta':0,'rc':1,None:2}[m[4]], int(m[5] or 0))


def logo(tag, dest):
    if subprocess.run(['git','cat-file','-e',f'{tag}:docs/logo.png'],stderr=subprocess.DEVNULL).returncode:
        subprocess.run(['git','fetch','--quiet','--depth=1','origin',f'refs/tags/{tag}:refs/tags/{tag}'],check=True)
    dest.write_bytes(command('git','show',f'{tag}:docs/logo.png'))


def font(size):
    for path in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','C:/Windows/Fonts/segoeui.ttf']:
        if Path(path).exists():
            return ImageFont.truetype(path,size)
    raise RuntimeError('Нужен шрифт с кириллицей')


def render_media(site, tag, temp, ref, paths, channel='stable'):
    directory = 'media' if channel == 'stable' else 'media/beta'
    media = site / directory
    media.mkdir(parents=True, exist_ok=True)
    cards = []
    folder = f'pack/{channel}'
    if channel == 'stable' and folder + '/manifest.json' not in paths:
        folder = 'pack'
    if folder + '/manifest.json' in paths:
        prefix = f'https://raw.githubusercontent.com/{REPO}/{ref}/{folder}/'
        def get(name, dest):
            subprocess.run(['curl','--fail','--silent','--show-error','--location','--retry','3',
                            prefix+name,'--output',str(dest)],check=True)
        get('manifest.json', temp/'pack.json')
        pack=json.loads((temp/'pack.json').read_text(encoding='utf-8'))
        def verified(file, dest):
            get(file, dest)
            if hashlib.sha256(dest.read_bytes()).hexdigest() != pack['files'][file]:
                raise ValueError(file)
        if pack['tag']==tag:
            for mode, view, label in VIEWS:
                file=f'ios/{mode}/{view}-framed-{mode}.webp'
                local=temp/(view+'.webp')
                verified(file,local)
                with Image.open(local) as source:
                    im = source.convert('RGBA')
                im.thumbnail((810, 1800), Image.Resampling.LANCZOS)
                filename = f'{view}-framed-{mode}.png'
                im.save(media / filename, optimize=True)
                cards.append({'imageURL': BASE_URL + directory + '/' + filename, 'width': im.width, 'height': im.height})
                # Предыдущие версии источника ссылаются на JPEG по постоянным адресам.
                legacy = Image.new('RGB', im.size, '#f8f8fd' if mode == 'light' else '#13151d')
                legacy.paste(im, mask=im.getchannel('A'))
                legacy.save(media / (view + '.jpg'), quality=91, subsampling=0, optimize=True)
            cover = 'mockups/overview.webp' if 'mockups/overview.webp' in pack['files'] else 'mockups/day.webp'
            if cover in pack['files']:
                verified(cover, temp/'cover.webp')
                with Image.open(temp/'cover.webp') as image:
                    ImageOps.fit(image.convert('RGB'), (1200,800), Image.Resampling.LANCZOS).save(
                        media/'header.jpg', quality=94, optimize=True)
                return cards
    if channel == 'beta':
        return cards
    bg=ImageOps.colorize(Image.linear_gradient('L').resize((1200,800)), '#e9eaff','#bdc9f1').convert('RGBA')
    draw=ImageDraw.Draw(bg)
    brand=Image.open(site/'icon.png').convert('RGBA')
    brand.thumbnail((152,152),Image.Resampling.LANCZOS)
    bg.alpha_composite(brand,(76,133))
    draw.text((65,321),'Journal',font=font(116),fill='#222b51')
    draw.text((76,487),'Расписание и дневник',font=font(42),fill='#37456f')
    draw.text((77,555),'МГТЭК',font=font(32),fill='#4b5980')
    bg.convert('RGB').save(media/'header.jpg',quality=92,optimize=True)
    return cards


def build():
    site=Path('site/ios')
    latest=json.loads(command('gh','api',f'repos/{REPO}/releases/latest'))
    pages=json.loads(command('gh','api','--paginate','--slurp',f'repos/{REPO}/releases?per_page=100'))
    betas=sorted((r for page in pages for r in page if r['prerelease'] and not r['draft']
                  and TAG.fullmatch(r['tag_name'])),key=key,reverse=True)
    with TemporaryDirectory() as tmp:
        temp=Path(tmp)
        cache = Path(os.environ.get('CATALOG_CACHE', str(temp/'cache')))
        cache.mkdir(parents=True, exist_ok=True)
        def source(r, beta):
            tag=r['tag_name']
            name=f'Journal-{tag}-ios.ipa'
            asset=next(a for a in r['assets'] if a['name']==name)
            notes=Path('.github/releases')/(tag+'.md')
            identity=hashlib.sha256(json.dumps([tag,asset['digest'],asset['size'],asset['browser_download_url'],
                                                r['published_at'],r['draft'],r['prerelease'],beta]).encode())
            identity.update(Path(__file__).with_name('altstore_source.py').read_bytes())
            if notes.exists():
                identity.update(notes.read_bytes())
            record=cache/(identity.hexdigest()+'.json')
            if record.exists():
                return json.loads(record.read_text(encoding='utf-8'))
            subprocess.run(['gh','release','download',tag,'--repo',REPO,'--pattern',name,'--dir',str(temp)],check=True)
            result=make_source(r,temp/name,beta=beta)
            record.write_text(json.dumps(result,ensure_ascii=False),encoding='utf-8')
            return result
        stable=source(latest,False)
        logo(latest['tag_name'],site/'icon.png')
        branch = command('git', 'ls-remote', 'origin', 'refs/heads/screenshots').decode().split()
        ref = branch[0] if branch else None
        paths = set()
        if ref:
            tree = json.loads(command('gh', 'api', f'repos/{REPO}/git/trees/{ref}?recursive=1'))
            paths = {entry['path'] for entry in tree['tree']}
        cards = render_media(site, latest['tag_name'], temp, ref, paths)
        if cards:
            stable['apps'][0]['screenshots']=cards
            stable['apps'][0]['screenshotURLs']=[c['imageURL'] for c in cards]
        beta=json.loads(json.dumps(stable))
        beta.update(name='Journal · Бета',identifier='eugggeneee.journal.beta.source',
                    sourceURL=BASE_URL+'beta.json',subtitle='Тестовые сборки Journal',iconURL=BASE_URL+'beta-icon.png',
                    description='Бета-версии и кандидаты в релиз. Основной источник Journal распространяет стабильные обновления.')
        app=beta['apps'][0]
        app.update(name='Journal · Бета',iconURL=beta['iconURL'],subtitle='Бета-версии и кандидаты в релиз')
        entries=[(latest,app['versions'][0])]
        privacy=dict(app['appPermissions']['privacy'])
        with ThreadPoolExecutor(max_workers=4) as pool:
            for release, catalog in zip(betas, pool.map(lambda r:source(r,True),betas)):
                item=catalog['apps'][0]
                entries.append((release,item['versions'][0]))
                for permission, reason in item['appPermissions']['privacy'].items():
                    privacy.setdefault(permission, reason)
        entries.sort(key=lambda pair:key(pair[0]),reverse=True)
        app['versions']=[v for _,v in entries]
        app['appPermissions']['privacy']=privacy
        app['localizedDescription']+=' Доступны бета-версии и кандидаты в релиз.'
        beta_cards = render_media(site, entries[0][0]['tag_name'], temp, ref, paths, 'beta')
        if beta_cards:
            beta['headerURL'] = BASE_URL + 'media/beta/header.jpg'
            app['screenshots'] = beta_cards
            app['screenshotURLs'] = [card['imageURL'] for card in beta_cards]
            app['localizedDescription'] += ' На скриншотах Journal ' + entries[0][0]['tag_name'][1:] + '.'
        elif cards:
            app['localizedDescription']+=' На скриншотах показан стабильный Journal '+latest['tag_name'][1:]+'.'
        logo(entries[0][0]['tag_name'],site/'beta-icon.png')
        for filename, catalog in [('source.json',stable),('beta.json',beta)]:
            (site/filename).write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        html=site/'index.html'
        gallery=''.join(f'<figure><img src="{c["imageURL"]}" width="{c["width"]}" height="{c["height"]}" alt="{label}"><figcaption>{label}</figcaption></figure>'
                        for (_,_,label),c in zip(VIEWS,cards))
        html.write_text(html.read_text(encoding='utf-8').replace('{{stable}}',latest['tag_name'][1:])
                        .replace('{{beta}}',entries[0][0]['tag_name'][1:])
                        .replace('{{ipa}}',stable['apps'][0]['versions'][0]['downloadURL'])
                        .replace('{{gallery}}',gallery),encoding='utf-8')


if __name__=='__main__':
    build()
