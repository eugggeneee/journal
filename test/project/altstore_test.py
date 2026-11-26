"""Контракт стабильного источника, независимо от GitHub и наличия iPhone."""
import hashlib
import plistlib
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts/release'))
from altstore_source import BASE_URL, BUNDLE_ID, make_source


class StableSourceTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.ipa = Path(temp.name) / 'Journal-v1.0.1-ios.ipa'
        info = {'CFBundleIdentifier': BUNDLE_ID, 'CFBundleShortVersionString': '1.0.1',
                'CFBundleVersion': '28', 'MinimumOSVersion': '15.0'}
        with zipfile.ZipFile(self.ipa, 'w') as archive:
            archive.writestr('Payload/Runner.app/Info.plist', plistlib.dumps(info))
        self.release = {'tag_name': 'v1.0.1', 'published_at': '2026-11-20T14:16:53Z',
                        'prerelease': False, 'draft': False, 'assets': [{
                            'name': self.ipa.name, 'size': self.ipa.stat().st_size,
                            'digest': 'sha256:' + hashlib.sha256(self.ipa.read_bytes()).hexdigest(),
                            'browser_download_url': 'https://example.org/' + self.ipa.name}]}

    def test_stable_install(self):
        catalog = make_source(self.release, self.ipa)
        self.assertEqual(catalog['sourceURL'], BASE_URL + 'stable.json')
        self.assertEqual(catalog['apps'][0]['versions'][0]['buildVersion'], '28')

    def test_prereleases_and_drafts_are_excluded(self):
        for patch in [{'draft': True}, {'prerelease': True}, {'tag_name': 'v1.0.1-beta.3'},
                      {'tag_name': 'v1.0.1-rc.1', 'prerelease': True}]:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                make_source({**self.release, **patch}, self.ipa)

    def test_rejects_damaged_asset(self):
        self.ipa.write_bytes(self.ipa.read_bytes() + b'x')
        with self.assertRaises(ValueError):
            make_source(self.release, self.ipa)
