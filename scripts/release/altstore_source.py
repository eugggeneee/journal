"""Собирает каталог AltStore Classic и SideStore из опубликованного IPA."""

import hashlib
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path

BUNDLE_ID = 'eugggeneee.journal'
BASE_URL = 'https://eugggeneee.github.io/journal/ios/'


def make_source(release: dict, ipa: Path) -> dict:
    tag = release['tag_name']
    match = re.fullmatch(r'v(\d+\.\d+\.\d+)', tag)
    if not match or release['draft'] or release['prerelease']:
        raise ValueError('Тег и канал выпуска не совпадают')
    name = f'Journal-{tag}-ios.ipa'
    asset = next(a for a in release['assets'] if a['name'] == name)
    if ipa.stat().st_size != asset['size'] or 'sha256:' + hashlib.sha256(ipa.read_bytes()).hexdigest() != asset['digest']:
        raise ValueError('IPA отличается от файла релиза')
    with zipfile.ZipFile(ipa) as archive:
        info = plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
    if info['CFBundleIdentifier'] != BUNDLE_ID or info['CFBundleShortVersionString'] != match[1]:
        raise ValueError('Идентификатор приложения или версия IPA не совпадают с релизом')

    version = {
        'version': info['CFBundleShortVersionString'],
        'buildVersion': info['CFBundleVersion'],
        'marketingVersion': tag[1:],
        'date': release['published_at'],
        'downloadURL': asset['browser_download_url'],
        'size': asset['size'],
        'minOSVersion': info['MinimumOSVersion'],
    }
    notes = Path('.github/releases') / f'{tag}.md'
    if notes.is_file():
        version['localizedDescription'] = notes.read_text(encoding='utf-8').strip()
    app = {
        'name': 'Journal',
        'bundleIdentifier': BUNDLE_ID,
        'developerName': 'eugggeneee',
        'subtitle': 'Расписание, отметки и пропуски МГТЭК',
        'category': 'utilities',
        'tintColor': '#5364A4',
        'localizedDescription': 'Когда начнётся следующая пара? Откройте главную, чтобы увидеть обратный отсчёт, кабинет и задания. '
                                'Отметки, пропуски и пометки привязаны к конкретной паре. Загруженное расписание доступно офлайн.',
        'iconURL': BASE_URL + 'icon.png',
        'versions': [version],
        # В release.yml Journal собирается без подписи и использует только основной пакет.
        'appPermissions': {'entitlements': [], 'privacy': {k: v for k, v in info.items() if 'UsageDescription' in k}},
    }
    return {
        'name': 'Journal',
        'identifier': BUNDLE_ID + '.source',
        'subtitle': 'Студенческий дневник МГТЭК',
        'description': 'Официальный источник Journal для iPhone и iPad.',
        'tintColor': '#5364A4',
        'iconURL': BASE_URL + 'icon.png',
        'headerURL': BASE_URL + 'media/header.jpg',
        'featuredApps': [BUNDLE_ID],
        'sourceURL': BASE_URL + 'stable.json',
        'website': BASE_URL,
        'apps': [app],
        'news': [],
    }


if __name__ == '__main__':
    metadata, ipa_file, output = map(Path, sys.argv[1:])
    source = make_source(json.loads(metadata.read_text(encoding='utf-8-sig')), ipa_file)
    output.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
