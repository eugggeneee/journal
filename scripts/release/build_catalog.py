"""Собрать стабильный каталог из IPA и галереи одного опубликованного тега."""
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory, mkdtemp

from PIL import Image
from altstore_source import BASE_URL, make_source

REPO = 'eugggeneee/journal'
VIEWS = [('home-default', 'Ход дня'), ('schedule', 'Расписание'), ('grades', 'Отметки'),
         ('absences', 'Пропуски'), ('tasks', 'Задания')]


def command(*args):
    return subprocess.check_output(args)


def download(url, dest):
    subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', '--retry', '3',
                    url, '--output', str(dest)], check=True)


def gallery(site, temp, tag, commit, ref):
    prefix = f'https://raw.githubusercontent.com/{REPO}/{ref}/pack/stable/'
    manifest = temp / 'manifest.json'
    download(prefix + 'manifest.json', manifest)
    pack = json.loads(manifest.read_text(encoding='utf-8'))
    if (pack['channel'], pack['tag'], pack['commit']) != ('stable', tag, commit):
        raise ValueError('Стабильная галерея для этого тега ещё не готова')

    def verified(name):
        local = temp / Path(name).name
        download(prefix + name, local)
        if hashlib.sha256(local.read_bytes()).hexdigest() != pack['files'][name]:
            raise ValueError(f'Неверная контрольная сумма {name}')
        return local

    # A changed gallery for the same release must also invalidate client image caches.
    path = f"media/{tag}-{hashlib.sha256(manifest.read_bytes()).hexdigest()[:12]}"
    media = site / path
    media.mkdir(parents=True)
    logo = command('git', 'show', f'{tag}:docs/logo.png')
    (media / 'icon.png').write_bytes(logo)
    shutil.copyfile(media / 'icon.png', site / 'icon.png')
    for mode, cover in [('light', 'overview'), ('dark', 'overview-dark')]:
        with Image.open(verified(f'mockups/{cover}.webp')) as image:
            image.thumbnail((1200, 800), Image.Resampling.LANCZOS)
            image.convert('RGB').save(media / f'header-{mode}.jpg', quality=94)
    shutil.copyfile(media / 'header-light.jpg', site / 'media/header.jpg')
    cards, figures = [], []
    for view, label in VIEWS:
        pair = {}
        for mode in ('light', 'dark'):
            filename = f'{view}-framed-{mode}'
            with Image.open(verified(f'ios/{mode}/{filename}.webp')) as src:
                image = src.convert('RGBA')
            image.thumbnail((810, 1800), Image.Resampling.LANCZOS)
            image.save(media / (filename + '.png'), optimize=True)
            url = BASE_URL + path + '/' + filename + '.png'
            cards.append({'imageURL': url, 'width': image.width, 'height': image.height})
            pair[mode] = url
        figures.append(f'<figure><picture><source media="(prefers-color-scheme: dark)" srcset="{pair["dark"]}">'
                       f'<img src="{pair["light"]}" width="{image.width}" height="{image.height}" alt="{label}"></picture>'
                       f'<figcaption>{label}</figcaption></figure>')
    return path, cards, ''.join(figures)


def build():
    release = json.loads(command('gh', 'api', f'repos/{REPO}/releases/latest'))
    tag = release['tag_name']
    if release['draft'] or release['prerelease'] or not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
        raise ValueError('Нужен опубликованный стабильный тег')
    subprocess.run(['git', 'fetch', '--quiet', '--depth=1', 'origin', f'refs/tags/{tag}:refs/tags/{tag}'], check=True)
    commit = command('git', 'rev-parse', tag + '^{commit}').decode().strip()
    ref = command('git', 'ls-remote', '--exit-code', 'origin', 'refs/heads/screenshots').decode().split()[0]
    # Pages deploys this fresh directory only after every artifact has passed validation.
    build_dir = Path('build')
    build_dir.mkdir(exist_ok=True)
    output = Path(mkdtemp(prefix='pages-', dir=build_dir)).resolve()
    for name in command('git', 'ls-files', '-z', '--', 'site').decode().split('\0'):
        if name:
            source = Path(name)
            dest = output / source.relative_to('site')
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, dest)
    site = output / 'ios'
    with TemporaryDirectory() as directory:
        temp = Path(directory)
        path, cards, figures = gallery(site, temp, tag, commit, ref)
        filename = f'Journal-{tag}-ios.ipa'
        subprocess.run(['gh', 'release', 'download', tag, '--repo', REPO,
                        '--pattern', filename, '--dir', str(temp)], check=True)
        catalog = make_source(release, temp / filename)
    app = catalog['apps'][0]
    app['iconURL'] = catalog['iconURL'] = BASE_URL + path + '/icon.png'
    catalog['headerURL'] = BASE_URL + path + '/header-light.jpg'
    app['screenshots'] = cards
    app['screenshotURLs'] = [card['imageURL'] for card in cards]
    content = json.dumps(catalog, ensure_ascii=False, indent=2) + '\n'
    for filename in ('stable.json', 'source.json'):
        (site / filename).write_text(content, encoding='utf-8')
    page = site / 'index.html'
    page.write_text(page.read_text(encoding='utf-8').replace('{{stable}}', tag[1:])
                    .replace('{{media}}', path).replace('{{gallery}}', figures)
                    .replace('{{ipa}}', app['versions'][0]['downloadURL']), encoding='utf-8')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
            print(f'path={output}', file=stream)
    print(output)


if __name__ == '__main__':
    build()
