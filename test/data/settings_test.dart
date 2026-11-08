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

  test('анимации и глубина: значения по умолчанию, сохранение и защита от мусора', () {
    final s = Settings();
    expect(s.motion, 0);
    expect(s.depth, isTrue);
    final back = Settings.fromJson(Settings(group: '6312', motion: 2, depth: false).toJson());
    expect(back.motion, 2);
    expect(back.depth, isFalse);
    final bad = Settings.fromJson({'group': '6312', 'mot': 7, 'dep': 'да'});
    expect(bad.motion, 0);
    expect(bad.depth, isTrue);
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
