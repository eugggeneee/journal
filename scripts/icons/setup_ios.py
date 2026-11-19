#!/usr/bin/env python3
"""Подключает наборы Icon Composer к ресурсам Runner и системному выбору значка."""
import hashlib
import json
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONS = os.path.join(ROOT, 'assets', 'icons')
RUNNER = os.path.join(ROOT, 'ios', 'Runner')
PBX = os.path.join(ROOT, 'ios', 'Runner.xcodeproj', 'project.pbxproj')

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


def install_icons(ids):
    source = os.path.join(ICONS, 'ios')
    names = ['AppIcon' if i == 'default' else 'Icon_' + i for i in ids]
    for name in names:
        folder = name + '.icon'
        shutil.copytree(os.path.join(source, folder), os.path.join(RUNNER, folder), dirs_exist_ok=True)
    # Этот каталог с одним стандартным значком создаёт flutter create.
    legacy = os.path.join(RUNNER, 'Assets.xcassets', 'AppIcon.appiconset')
    if os.path.isdir(legacy):
        shutil.rmtree(legacy)
    with open(PBX, encoding='utf-8') as f:
        project = f.read()
    # Привязываем значки к той же группе и фазе ресурсов, что и Assets.xcassets.
    for name in names:
        resource = name + '.icon'
        ref, build = [hashlib.sha256((resource + k).encode()).hexdigest()[:24].upper() for k in ('ref', 'build')]
        if f'{build} /* {resource} in Resources */,' in project:
            continue
        entries = [
            ('/* End PBXFileReference section */', f'\t\t{ref} /* {resource} */ = {{isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon; path = {resource}; sourceTree = "<group>"; }};'),
            ('/* End PBXBuildFile section */', f'\t\t{build} /* {resource} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {resource} */; }};'),
        ]
        for comment, entry in [('Assets.xcassets', f'{ref} /* {resource} */,'), ('Assets.xcassets in Resources', f'{build} /* {resource} in Resources */,')]:
            anchor = re.search(r'^\s*[0-9A-F]{24} /\* ' + re.escape(comment) + r' \*/,\s*$', project, re.M)
            if not anchor:
                raise ValueError('Не найдена группа Runner: ' + comment)
            entries.append((anchor.group(0), '\t\t\t\t' + entry))
        for anchor, entry in entries:
            if project.count(anchor) != 1:
                raise ValueError('Неоднозначная структура проекта: ' + anchor)
            project = project.replace(anchor, entry + '\n' + anchor)
    key = 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES'
    project = re.sub(r'^[ \t]*' + key + r' = .*?;\n', '', project, flags=re.M)
    pattern = r'^([ \t]*)ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;$'
    alternatives = ' '.join(n for n in names if n != 'AppIcon')
    project, count = re.subn(pattern, lambda m: m[0] + '\n' + m[1] + key + ' = "' + alternatives + '";', project, flags=re.M)
    if not count:
        raise ValueError('Не найдена настройка основного значка Runner')
    with open(PBX, 'w', encoding='utf-8') as f:
        f.write(project)


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
    with open(os.path.join(ICONS, 'icons.json'), encoding='utf-8') as f:
        install_icons(json.load(f))
    if not patch_delegate():
        raise RuntimeError('Не удалось подключить канал в AppDelegate.swift')


if __name__ == '__main__':
    main()
