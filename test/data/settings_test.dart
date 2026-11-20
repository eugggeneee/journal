import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/app_icons.dart';
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

  testWidgets('при временном отказе iOS смена значка повторяется один раз', (tester) async {
    const channel = MethodChannel('eugggeneee.journal/app_icon');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      var attempts = 0;
      final requested = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'get') return 'default';
        requested.add(call.arguments['id'] as String);
        if (++attempts == 1) throw PlatformException(code: 'NSPOSIXErrorDomain', details: 35);
        return true;
      });
      final change = AppIcons.set('teal');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(await change, isTrue);
      expect(attempts, 2);
      expect(requested, ['teal', 'teal']);

      attempts = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        attempts++;
        throw PlatformException(code: 'unsupported');
      });
      expect(await AppIcons.set('teal'), isFalse);
      expect(attempts, 1);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('применённый iOS значок остаётся выбранным при ошибке подтверждения', (tester) async {
    const channel = MethodChannel('eugggeneee.journal/app_icon');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'get') return 'teal';
        throw PlatformException(code: 'NSPOSIXErrorDomain', details: 5);
      });
      expect(await AppIcons.set('teal'), isTrue);
      expect(calls, ['set', 'get']);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('для каждой темы есть значок приложения', () {
    final ids = (jsonDecode(File('assets/icons/icons.json').readAsStringSync()) as List).cast<String>();
    expect(AppPalette.choices.map((c) => c.id).toList(), ids);
    for (final id in ids) {
      final name = id == 'default' ? 'AppIcon' : 'Icon_$id';
      final base = 'assets/icons/ios/$name.icon';
      final spec = jsonDecode(File('$base/icon.json').readAsStringSync());
      for (final group in spec['groups']) {
        for (final layer in group['layers']) {
          expect(File('$base/Assets/${layer['image-name']}').existsSync(), isTrue);
        }
      }
      final key = id.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
      final launcher = id == 'default' ? 'ic_launcher' : 'ic_launcher_$key';
      for (final suffix in ['', '_round']) {
        expect(File('assets/icons/android/mipmap-anydpi-v26/$launcher$suffix.xml').existsSync(), isTrue);
        for (final density in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']) {
          expect(File('assets/icons/android/mipmap-$density/$launcher$suffix.png').existsSync(), isTrue);
        }
      }
      expect(File('assets/icons/preview/$id.png').existsSync(), isTrue, reason: 'preview/$id.png');
    }
  });

  test('цели, порядок блоков главной и подсказка сохраняются и читаются', () {
    final s = Settings(
      goals: {'Математика': 9, 'Физика': 8},
      homeOrder: [kBlockRecent, kBlockMetrics],
      homeHidden: [kBlockWeek],
      weekView: true,
      tipGestures: true,
    );
    final back = Settings.fromJson(s.toJson());
    expect(back.goals, {'Математика': 9, 'Физика': 8});
    // недостающие блоки дописываются в конец в обычном порядке
    expect(back.homeOrder, [kBlockRecent, kBlockMetrics, kBlockTasks, kBlockTomorrow, kBlockWeek]);
    expect(back.homeHidden, [kBlockWeek]);
    expect(back.weekView, isTrue);
    expect(back.tipGestures, isTrue);
  });

  test('мусор в целях и блоках игнорируется', () {
    final s = Settings.fromJson({
      'group': '6312',
      'goal': {'Математика': 11, 'Физика': 0, '': 8, 'Химия': 7},
      'ho': ['x', kBlockWeek, kBlockWeek],
      'hh': ['y', kBlockTasks],
    });
    expect(s.goals, {'Химия': 7});
    expect(s.homeOrder.first, kBlockWeek);
    expect(s.homeOrder.toSet().length, kHomeBlocks.length);
    expect(s.homeHidden, [kBlockTasks]);
  });

  test('по умолчанию все блоки видны в обычном порядке', () {
    final s = Settings();
    expect(s.homeOrder, kHomeBlocks);
    expect(s.homeHidden, isEmpty);
    expect(s.goals, isEmpty);
    expect(s.weekView, isFalse);
    expect(s.tipGestures, isFalse);
  });

  test('задание: сохранение, чтение и повреждённые записи', () {
    final t = Task(id: 't1', text: 'Сдать реферат', due: DateTime(2026, 11, 20), subject: 'Физика', date: DateTime(2026, 11, 16), lesson: 2, homework: false, done: true);
    final back = Task.tryFromJson(t.toJson())!;
    expect(back.text, 'Сдать реферат');
    expect(back.due, DateTime(2026, 11, 20));
    expect(back.subject, 'Физика');
    expect(back.date, DateTime(2026, 11, 16));
    expect(back.lesson, 2);
    expect(back.homework, isFalse);
    expect(back.done, isTrue);
    expect(Task.tryFromJson({'t': '', 'due': '2026-11-20'}), isNull);
    expect(Task.tryFromJson({'t': 'x', 'due': 'вчера'}), isNull);
    expect(Task.tryFromJson('мусор'), isNull);
  });
}
