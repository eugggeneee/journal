"""Снять настоящий экран только после подтверждения готовности Flutter-кадра."""
import argparse
import json
import os
import re
import subprocess
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from threading import Thread


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def iphone():
    inventory = json.loads(run('xcrun', 'simctl', 'list', '--json'))
    types = {row['identifier']: row['name'] for row in inventory['devicetypes']}
    choices = []
    for runtime in inventory['runtimes']:
        if not runtime['isAvailable'] or not runtime['identifier'].split('.')[-1].startswith('iOS-'):
            continue
        for device in runtime.get('supportedDeviceTypes', []):
            ident = device['identifier']
            name = types.get(ident, device['name'])
            if name == 'iPhone 17' and runtime['version'] == '26.2':
                choices.append((ident, runtime['identifier'], name, runtime['version']))
    if not choices:
        raise RuntimeError('gallery-v1 требует симулятор iPhone 17 с iOS 26.2')
    typ, runtime, name, version = choices[0]
    udid = run('xcrun', 'simctl', 'create', 'Journal pack', typ, runtime)
    run('xcrun', 'simctl', 'boot', udid)
    run('open', '-a', run('xcode-select', '-p') + '/Applications/Simulator.app',
        '--args', '-CurrentDeviceUDID', udid)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], timeout=360, check=True)
    run('xcrun', 'simctl', 'spawn', udid, 'defaults', 'write', 'NSGlobalDomain', 'AppleLanguages', '-array', 'ru', 'en')
    run('xcrun', 'simctl', 'spawn', udid, 'defaults', 'write', 'NSGlobalDomain', 'AppleLocale', 'ru_BY')
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '11:10', '--batteryState',
        'discharging', '--batteryLevel', '100', '--cellularBars', '4', '--wifiBars', '3')
    return udid, {'model': name, 'environment': 'iOS Simulator', 'os': version}


def capture(app, output):
    device, info = iphone()
    output.mkdir(parents=True, exist_ok=True)
    (output/'device.json').write_text(json.dumps(info, ensure_ascii=False), encoding='utf-8')

    class Capture(BaseHTTPRequestHandler):
        def do_POST(self):
            if not re.fullmatch(r'/(light|dark)/[A-Za-z0-9-]+', self.path):
                self.send_error(400)
                return
            dest = output / (self.path[1:] + '.png')
            try:
                dest.parent.mkdir(exist_ok=True)
                # Дождаться композиции SpringBoard после последнего Flutter-кадра.
                time.sleep(.25)
                run('xcrun', 'simctl', 'io', device, 'screenshot', str(dest))
                self.send_response(204)
                self.end_headers()
            except (OSError, subprocess.SubprocessError) as exc:
                self.send_error(500, str(exc))

    server = HTTPServer(('127.0.0.1',8765), Capture)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        target = 'integration_test/journal_screens_test.dart'
        version = '--dart-define=JOURNAL_VERSION=' + os.environ['TAG'][1:]
        subprocess.run(['flutter','test','--no-pub','--no-dds','-v','-d',device,'--reporter','expanded',version,
                        '--dart-define=JOURNAL_CLOCK=2026-11-18T11:10:00',target],
                       cwd=app,check=True,timeout=1800)
    finally:
        server.shutdown()
        server.server_close()
        subprocess.run(['xcrun','simctl','shutdown',device])
        subprocess.run(['xcrun','simctl','delete',device])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    capture(args.app.resolve(), args.output.resolve())
