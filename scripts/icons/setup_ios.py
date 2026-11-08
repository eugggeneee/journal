#!/usr/bin/env python3
"""Добавляет в сгенерированный iOS-проект альтернативные значки приложения.

Запускается в CI после `flutter create` и `dart run flutter_launcher_icons`:
  1) для каждой темы создаётся набор значков Icon_<id>.appiconset в Assets.xcassets;
     в каждом наборе три варианта iOS 18+: обычный, тёмный и тонированный (оттенки серого);
  2) обычный AppIcon заменяется таким же набором из трёх вариантов;
  3) в настройки сборки добавляется ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES;
  4) в AppDelegate.swift регистрируется канал `eugggeneee.journal/app_icon`.
Если какой-то шаг не удаётся, скрипт печатает предупреждение и не ломает сборку.
"""
import json
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONS = os.path.join(ROOT, 'assets', 'icons')
RUNNER = os.path.join(ROOT, 'ios', 'Runner')
PBX = os.path.join(ROOT, 'ios', 'Runner.xcodeproj', 'project.pbxproj')

CONTENTS = '''{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon_dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon_tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
'''

SWIFT = '''

/// Смена значка приложения (канал для экрана «Тема и значок»).
final class AppIconChannel {
  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AppIconChannel") else { return }
    let channel = FlutterMethodChannel(name: "eugggeneee.journal/app_icon", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "get":
        let name = UIApplication.shared.alternateIconName
        if let name = name, name.hasPrefix("Icon_") {
          result(String(name.dropFirst(5)))
        } else {
          result("default")
        }
      case "set":
        let args = call.arguments as? [String: Any]
        guard let id = args?["id"] as? String else { result(false); return }
        DispatchQueue.main.async {
          guard UIApplication.shared.supportsAlternateIcons else { result(false); return }
          let name: String? = (id == "default") ? nil : "Icon_" + id
          UIApplication.shared.setAlternateIconName(name) { error in result(error == nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
'''


def warn(msg):
    print(f'::warning::{msg}')


def write_set(folder, icon_id):
    """Набор значков из трёх вариантов: обычный, тёмный и тонированный."""
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):
        if name.endswith('.png'):
            os.remove(os.path.join(folder, name))
    src = os.path.join(ICONS, icon_id)
    shutil.copy(os.path.join(src, 'ios.png'), os.path.join(folder, 'icon.png'))
    shutil.copy(os.path.join(src, 'ios_dark.png'), os.path.join(folder, 'icon_dark.png'))
    shutil.copy(os.path.join(src, 'ios_tinted.png'), os.path.join(folder, 'icon_tinted.png'))
    with open(os.path.join(folder, 'Contents.json'), 'w', encoding='utf-8') as f:
        f.write(CONTENTS)


def make_sets(ids):
    names = []
    cat = os.path.join(RUNNER, 'Assets.xcassets')
    if not os.path.isdir(cat):
        return None
    for icon_id in ids:
        if icon_id == 'default':
            # обычный значок: заменяем набор flutter_launcher_icons, чтобы появились тёмный и тонированный варианты
            write_set(os.path.join(cat, 'AppIcon.appiconset'), 'default')
            continue
        name = f'Icon_{icon_id}'
        write_set(os.path.join(cat, f'{name}.appiconset'), icon_id)
        names.append(name)
    return names


def patch_pbx(names):
    s = open(PBX, encoding='utf-8').read()
    if 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' in s:
        return True
    pat = re.compile(r'^(\s*)ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;$', re.M)
    if not pat.search(s):
        return False
    value = ' '.join(names)
    s = pat.sub(lambda m: f'{m.group(0)}\n{m.group(1)}ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "{value}";', s)
    open(PBX, 'w', encoding='utf-8').write(s)
    return True


def patch_delegate():
    path = os.path.join(RUNNER, 'AppDelegate.swift')
    s = open(path, encoding='utf-8').read()
    if 'AppIconChannel' in s:
        return True
    implicit = 'GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)'
    classic = 'GeneratedPluginRegistrant.register(with: self)'
    if implicit in s:
        s = s.replace(implicit, implicit + '\n    AppIconChannel.register(with: engineBridge.pluginRegistry)', 1)
    elif classic in s:
        s = s.replace(classic, classic + '\n    AppIconChannel.register(with: self)', 1)
    else:
        return False
    open(path, 'w', encoding='utf-8').write(s + SWIFT)
    return True


def main():
    if not os.path.isdir(RUNNER):
        warn('Папка ios/Runner не найдена (сначала flutter create)')
        return 0
    ids = json.load(open(os.path.join(ICONS, 'icons.json'), encoding='utf-8'))
    names = make_sets(ids)
    if not names:
        warn('Assets.xcassets не найден — альтернативные значки не добавлены')
        return 0
    if not patch_pbx(names):
        warn('Не удалось прописать альтернативные значки в project.pbxproj — смена значка не заработает')
        return 0
    if not patch_delegate():
        warn('Не удалось подключить канал в AppDelegate.swift — смена значка не заработает')
        return 0
    print(f'Альтернативные значки добавлены: {len(names)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
