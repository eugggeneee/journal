"""Keep the required check present for docs PRs without booting simulators."""
import os
from pathlib import Path
import re
import subprocess

full = True
if os.environ.get('EVENT_NAME') == 'pull_request':
    base = os.environ['PR_BASE_SHA']
    if not re.fullmatch(r'[0-9a-f]{40}', base):
        raise SystemExit('Invalid base commit')
    subprocess.run(['git', 'fetch', '--no-tags', '--depth=1', 'origin', base], check=True)
    names = subprocess.check_output(['git', 'diff', '--name-only', base, 'HEAD'], text=True).splitlines()
    prefixes = ('App/', 'AppTests/', 'UITests/', 'Sources/', 'Tests/', 'scripts/', 'Journal.xcodeproj/', '.github/workflows/')
    files = {'Package.swift', 'Package.resolved', 'version.json'}
    full = any(name.startswith(prefixes) or name in files for name in names)
with Path(os.environ['GITHUB_OUTPUT']).open('a', encoding='utf-8') as output:
    output.write(f'full={str(full).lower()}\n')
print('Full iOS verification' if full else 'Documentation-only: core and generated-project verification')
