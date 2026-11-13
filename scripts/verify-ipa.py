"""Check the distributable, not just the archive directory."""
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    names = set(archive.namelist())
    info = plistlib.loads(archive.read('Payload/Journal.app/Info.plist'))
    assert info['CFBundleIdentifier'] == 'eugggeneee.journal.app'
    assert info['MinimumOSVersion'] == '18.0'
    assert info['UIDeviceFamily'] == [1]
    assert 'Payload/Journal.app/Journal' in names
    assert 'Payload/Journal.app/Assets.car' in names
    assert 'Payload/Journal.app/PrivacyInfo.xcprivacy' in names
    assert not any('embedded.mobileprovision' in n for n in names)
    print('IPA verified: iPhone, iOS 18+, correct bundle ID, assets and privacy manifest.')
