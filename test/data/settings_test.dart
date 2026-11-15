import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/palette.dart';
import 'package:journal/data/models.dart';

void main() {
  test('старые данные с группой считаются пройденным приветствием', () {
    final s = Settings.fromJson({'group': '6312', 'extra': <String>[]});
    expect(s.onboarded, isTrue);
    expect(s.absenceHours, 2);
    expect(s.themeMode, 0);
  });

  test('новая установка без группы показывает приветствие', () {
    expect(Settings.fromJson(null).onboarded, isFalse);
  });

  test('некорректные значения заменяются безопасными', () {
    final s = Settings.fromJson({'group': 'x', 'theme': 9, 'ah': 7});
    expect(s.themeMode, 0);
    expect(s.absenceHours, 2);
  });

  test('цветовая тема по умолчанию — «как в системе», и она сохраняется', () {
    expect(Settings().themeColor, 'auto');
    expect(Settings.fromJson({'group': '6312'}).themeColor, 'auto');
    final back = Settings.fromJson(Settings(group: '6312', themeColor: 'teal').toJson());
    expect(back.themeColor, 'teal');
  });

  test('анимации: значение по умолчанию, сохранение и защита от мусора', () {
    expect(Settings().motion, 0);
    final back = Settings.fromJson(Settings(group: '6312', motion: 2).toJson());
    expect(back.motion, 2);
    expect(Settings.fromJson({'group': '6312', 'mot': 7}).motion, 0);
  });

  test('свёрнутая карточка дня сохраняется, по умолчанию развёрнута', () {
    expect(Settings().dayCardFolded, isFalse);
    final back = Settings.fromJson(Settings(group: '6312', dayCardFolded: true).toJson());
    expect(back.dayCardFolded, isTrue);
    expect(Settings.fromJson({'group': '6312', 'dc': 'да'}).dayCardFolded, isFalse);
  });

  test('устаревший ключ в копии настроек не мешает чтению', () {
    final s = Settings.fromJson({'group': '6312', 'dep': false, 'mot': 1});
    expect(s.group, '6312');
    expect(s.motion, 1);
  });

  test('неизвестная тема заменяется стандартной', () {
    expect(AppPalette.has('teal'), isTrue);
    expect(AppPalette.has('nope'), isFalse);
    expect(AppPalette.byId('nope').id, AppPalette.standardId);
  });

  test('для каждой темы есть значок приложения', () {
    final ids = (jsonDecode(File('assets/icons/icons.json').readAsStringSync()) as List).cast<String>();
    expect(AppPalette.choices.map((c) => c.id).toList(), ids);
    for (final id in ids) {
      for (final f in ['ios', 'ios_dark', 'ios_tinted', 'fg', 'bg', 'legacy']) {
        expect(File('assets/icons/$id/$f.png').existsSync(), isTrue, reason: '$id/$f.png');
      }
      expect(File('assets/icons/preview/$id.png').existsSync(), isTrue, reason: 'preview/$id.png');
    }
  });
}
