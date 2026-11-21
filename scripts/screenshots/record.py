"""Снять настоящий экран только после подтверждения готовности Flutter-кадра."""
import argparse
import json
import os
import re
import subprocess
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from threading import Event, Thread


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
            if re.fullmatch(r'iPhone \d+', name):
                choices.append((int(name.split()[-1]), tuple(map(int, runtime['version'].split('.'))),
                                ident, runtime['identifier'], name, runtime['version']))
    _, _, typ, runtime, name, version = max(choices)
    udid = run('xcrun', 'simctl', 'create', 'Journal pack', typ, runtime)
    run('xcrun', 'simctl', 'boot', udid)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], timeout=360, check=True)
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '11:10', '--batteryState',
        'discharging', '--batteryLevel', '100', '--cellularBars', '4', '--wifiBars', '3')
    return udid, {'model': name, 'environment': 'iOS Simulator', 'os': version}


def android():
    serial = run('adb', 'get-serialno')
    run('adb', 'shell', 'wm', 'size', '1080x2340')
    run('adb', 'shell', 'wm', 'density', '420')
    run('adb', 'shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1')
    for fields in [['enter'], ['clock','--es','hhmm','1110'], ['battery','--es','level','100','--es','plugged','false']]:
        run('adb', 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', *fields)
    run('adb', 'reverse', 'tcp:8765', 'tcp:8765')
    return serial, {'model': 'Samsung Galaxy S26', 'environment': 'Android Emulator (AOSP), профиль Galaxy S26',
                    'os': run('adb', 'shell', 'getprop', 'ro.build.version.release')}


def capture(platform, app, output):
    device, info = iphone() if platform == 'ios' else android()
    output.mkdir(parents=True, exist_ok=True)
    (output/'device.json').write_text(json.dumps(info, ensure_ascii=False), encoding='utf-8')

    completed = Event()

    class Capture(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/complete':
                self.send_response(204)
                self.end_headers()
                completed.set()
                return
            if not re.fullmatch(r'/(light|dark)/[A-Za-z0-9-]+', self.path):
                self.send_error(400)
                return
            dest = output / (self.path[1:] + '.png')
            try:
                dest.parent.mkdir(exist_ok=True)
                # Дождаться композиции SurfaceFlinger / SpringBoard после последнего Flutter-кадра.
                time.sleep(.25)
                if platform == 'ios':
                    run('xcrun', 'simctl', 'io', device, 'screenshot', str(dest))
                else:
                    with dest.open('wb') as image:
                        subprocess.run(['adb','-s',device,'exec-out','screencap','-p'], stdout=image, check=True, timeout=25)
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
        if platform == 'android':
            # Launch the published app's real alias directly. Capturing the display
            # needs neither a Dart debugger connection nor a forwarded VM-service port.
            subprocess.run(['flutter','build','apk','--debug','--no-pub',version,'--target',target],
                           cwd=app,check=True,timeout=1200)
            run('adb','-s',device,'install','-r',str(app/'build/app/outputs/flutter-apk/app-debug.apk'))
            run('adb','-s',device,'logcat','-c')
            run('adb','-s',device,'shell','am','start','-W','-n','eugggeneee.journal/.Icon_default')
            for _ in range(60):
                if completed.wait(12):
                    break
                logs = run('adb','-s',device,'logcat','-d','-s','flutter:I','AndroidRuntime:E')
                if 'Some tests failed' in logs or 'FATAL EXCEPTION' in logs:
                    raise RuntimeError(logs[-7000:])
            else:
                raise TimeoutError('Android did not finish capturing: ' + logs[-7000:])
        else:
            subprocess.run(['flutter','test','--no-pub','-d',device,'--reporter','expanded',version,target],
                           cwd=app,check=True,timeout=1800)
    finally:
        server.shutdown()
        server.server_close()
        if platform == 'ios':
            subprocess.run(['xcrun','simctl','shutdown',device])
            subprocess.run(['xcrun','simctl','delete',device])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=['ios','android'])
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    capture(args.platform, args.app.resolve(), args.output.resolve())
