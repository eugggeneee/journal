"""Вывести тег последнего опубликованного выпуска выбранного канала."""
import json
import os
import re
import subprocess
import sys


def latest(channel):
    api = f"repos/{os.environ['GITHUB_REPOSITORY']}/releases"
    if channel == 'stable':
        release = json.loads(subprocess.check_output(['gh', 'api', api + '/latest']))
        if not release['draft'] and not release['prerelease'] and re.fullmatch(r'v\d+\.\d+\.\d+', release['tag_name']):
            return release['tag_name']
    elif channel == 'beta':
        pages = json.loads(subprocess.check_output(['gh', 'api', '--paginate', '--slurp', api + '?per_page=100']))
        tags = {}
        for page in pages:
            for r in page:
                match = re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)-beta\.(\d+)', r['tag_name'])
                if match and r['prerelease'] and not r['draft']:
                    tags[tuple(map(int, match.groups()))] = r['tag_name']
        if tags:
            return tags[max(tags)]
    raise SystemExit(f'Нет опубликованной версии для канала {channel}')


if __name__ == '__main__':
    print(latest(sys.argv[1]))
