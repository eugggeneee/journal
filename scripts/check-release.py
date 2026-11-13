import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
release = json.loads((root / 'version.json').read_text())
expected = 'v' + release['release']
assert sys.argv[1] == expected, f'Tag must match version.json: {expected}'
assert re.fullmatch(r'v\d+\.\d+\.\d+(?:-beta\.\d+)?', expected), 'Unexpected release tag'
assert release['marketing'] == release['release'].split('-')[0]
assert (root / f'docs/releases/{expected}.md').is_file(), 'Release notes are required'
print('Release metadata verified:', expected)
