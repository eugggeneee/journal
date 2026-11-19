#!/usr/bin/env python3
"""Устанавливает готовые ресурсы Android и сохраняет имена алиасов при обновлении."""
import glob
import json
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONS = os.path.join(ROOT, 'assets', 'icons')
ANDROID = os.path.join(ROOT, 'android', 'app', 'src', 'main')


def warn(msg):
    print(f'::warning::{msg}')


def res_key(icon_id):
    """deepPurple → deep_purple (в именах ресурсов Android нет заглавных букв)."""
    return re.sub(r'([A-Z])', lambda m: '_' + m.group(1).lower(), icon_id)


def copy_resources(ids):
    res = os.path.join(ANDROID, 'res')
    source = os.path.join(ICONS, 'android')
    for icon_id in ids:
        name = 'ic_launcher' if icon_id == 'default' else 'ic_launcher_' + res_key(icon_id)
        for density in ('mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi', 'anydpi-v26'):
            extension = '.xml' if density == 'anydpi-v26' else '.png'
            for suffix in ('', '_round'):
                path = os.path.join(source, 'mipmap-' + density, name + suffix + extension)
                if not os.path.isfile(path):
                    raise FileNotFoundError(path)
    shutil.copytree(source, res, dirs_exist_ok=True)


def patch_manifest(ids):
    path = os.path.join(ANDROID, 'AndroidManifest.xml')
    s = open(path, encoding='utf-8').read()
    if 'activity-alias' in s:
        print('Манифест уже содержит алиасы — пропускаю')
        return True
    m = re.search(r'<activity\b[^>]*android:name="[^"]*MainActivity"[^>]*>.*?</activity>', s, re.S)
    if not m:
        warn('Не найден MainActivity в AndroidManifest.xml — смена значка отключена')
        return False
    block = m.group(0)
    new_block = re.sub(r'\s*<category android:name="android.intent.category.LAUNCHER"\s*/>', '', block)
    if new_block == block:
        warn('В MainActivity нет категории LAUNCHER — смена значка отключена')
        return False
    s = s.replace(block, new_block)

    aliases = []
    for icon_id in ids:
        icon = '@mipmap/ic_launcher' if icon_id == 'default' else f'@mipmap/ic_launcher_{res_key(icon_id)}'
        enabled = 'true' if icon_id == 'default' else 'false'
        aliases.append(
            f'        <activity-alias android:name=".Icon_{icon_id}" android:targetActivity=".MainActivity"\n'
            f'            android:enabled="{enabled}" android:exported="true" android:icon="{icon}" android:roundIcon="{icon}_round">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.MAIN"/>\n'
            '                <category android:name="android.intent.category.LAUNCHER"/>\n'
            '            </intent-filter>\n'
            '        </activity-alias>\n')
    idx = s.rindex('</application>')
    s = s[:idx] + ''.join(aliases) + '    ' + s[idx:]
    open(path, 'w', encoding='utf-8').write(s)
    return True


KOTLIN = '''package %(pkg)s

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val iconIds = listOf(%(ids)s)

    private fun component(id: String) = ComponentName(packageName, "%(pkg)s.Icon_$id")

    private fun isOn(id: String): Boolean {
        val state = packageManager.getComponentEnabledSetting(component(id))
        return state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && id == "default")
    }

    private fun apply(id: String): Boolean = try {
        // сначала включаем новый значок, потом выключаем остальные — приложение не остаётся без значка
        packageManager.setComponentEnabledSetting(
            component(id), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (other in iconIds) {
            if (other != id) {
                packageManager.setComponentEnabledSetting(
                    component(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
        true
    } catch (e: Exception) {
        false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eugggeneee.journal/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> result.success(iconIds.firstOrNull { isOn(it) } ?: "default")
                    "set" -> {
                        val id = call.argument<String>("id")
                        result.success(id != null && id in iconIds && apply(id))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
'''


def patch_activity(ids):
    files = glob.glob(os.path.join(ANDROID, 'kotlin', '**', 'MainActivity.kt'), recursive=True) + \
            glob.glob(os.path.join(ANDROID, 'java', '**', 'MainActivity.kt'), recursive=True)
    if not files:
        warn('MainActivity.kt не найден — смена значка отключена')
        return False
    path = files[0]
    pkg = re.search(r'^package\s+([\w.]+)', open(path, encoding='utf-8').read(), re.M)
    if not pkg:
        warn('Не удалось определить пакет MainActivity — смена значка отключена')
        return False
    code = KOTLIN % {'pkg': pkg.group(1), 'ids': ', '.join(f'"{i}"' for i in ids)}
    open(path, 'w', encoding='utf-8').write(code)
    return True


def main():
    if not os.path.isdir(ANDROID):
        warn('Папка android/ не найдена (сначала flutter create)')
        return 1
    ids = json.load(open(os.path.join(ICONS, 'icons.json'), encoding='utf-8'))
    # Манифест правим только если получилось подготовить и код, и ресурсы — иначе значок пропадёт.
    copy_resources(ids)
    if patch_activity(ids) and patch_manifest(ids):
        print(f'Смена значка настроена: {len(ids)} значков')
    else:
        raise RuntimeError('Не удалось подключить смену значка')
    return 0


if __name__ == '__main__':
    sys.exit(main())
