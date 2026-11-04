import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';
import 'package:journal/data/store.dart';
import 'package:journal/logic/bells.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('профиль звонков: будни и суббота выбираются отдельно', () {
    expect(bellKeyFor(DateTime(2026, 11, 4)), kBellWeek);
    expect(bellKeyFor(DateTime(2026, 11, 6)), kBellWeek);
    expect(bellKeyFor(DateTime(2026, 11, 7)), kBellSat);
  });

  test('две половины пары по 45 минут и перерыв между ними', () {
    const s = BellSlot(start: 8 * 60 + 30, end: 10 * 60 + 5, breakStart: 9 * 60 + 15, breakEnd: 9 * 60 + 20);
    expect(s.valid, isTrue);
    expect(s.firstHalf, 45);
    expect(s.secondHalf, 45);
    expect(s.breakMinutes, 5);
    expect(halvesText(s), '45 + 45 мин');
    expect(halvesText(const BellSlot(start: 510, end: 600)), '90 мин');
  });

  test('автозаполнение: пары подряд, обед после выбранной', () {
    final p = generateBells(const BellPlan(firstStart: 8 * 60 + 30, pairMinutes: 90, breakMinutes: 10, lunchAfter: 2, lunchMinutes: 40));
    expect(p.slots.length, 7);
    expect(p[1]!.start, 8 * 60 + 30);
    expect(p[1]!.end, 10 * 60);
    expect(p[2]!.start, 10 * 60 + 10);
    expect(p.gapAfter(1), 10);
    expect(p.gapAfter(2), 40);
    expect(p.isLunchAfter(2), isTrue);
    expect(gapLabel(p, 2), 'Обед 40 мин');
    expect(gapLabel(p, 1), 'Перерыв 10 мин');
    expect(gapLabel(p, 7), isNull);
    expect(p.problem, isNull);
  });

  test('перерыв внутри пары ставится посередине и проходит проверку', () {
    final p = generateBells(const BellPlan(pairMinutes: 90, innerBreak: 10, count: 1));
    final s = p[1]!;
    expect(s.hasBreak, isTrue);
    expect(s.breakMinutes, 10);
    expect(s.valid, isTrue);
  });

  group('готовые расписания колледжа', () {
    BellPreset preset(String id) => kBellPresets.firstWhere((p) => p.id == id);

    test('все корректны, подходят к своим дням', () {
      expect(kBellPresets.length, 3);
      for (final p in kBellPresets) {
        expect(p.profile.problem, isNull, reason: p.id);
        for (final s in p.profile.slots.values) {
          expect(s.valid, isTrue, reason: p.id);
          expect(s.hasBreak, isTrue, reason: p.id);
        }
      }
      expect(preset('week1').key, kBellWeek);
      expect(preset('week2').key, kBellWeek);
      expect(preset('sat').key, kBellSat);
    });

    test('расписание 1: обед между 2 и 3 парой, 3 пара с 12:20', () {
      final p = preset('week1').profile;
      expect(p.slots.length, 7);
      expect(p[1]!.start, 8 * 60 + 20);
      expect(p[1]!.firstHalf, 45);
      expect(p[1]!.breakMinutes, 10);
      expect(p[3]!.start, 12 * 60 + 20);
      expect(p[3]!.end, 14 * 60);
      expect(p.lunchAfter, 2);
      expect(gapLabel(p, 2), 'Обед 30 мин');
      expect(gapLabel(p, 1), 'Перерыв 10 мин');
      expect(p[4]!.breakMinutes, 5);
      expect(p[7]!.end, 21 * 60);
    });

    test('расписание 2: обед внутри 3 пары', () {
      final p = preset('week2').profile;
      final s = p[3]!;
      expect(s.start, 12 * 60);
      expect(s.breakStart, 12 * 60 + 45);
      expect(s.breakEnd, 13 * 60 + 15);
      expect(s.end, 14 * 60);
      expect(s.lunchInside, isTrue);
      expect(innerBreakWord(s), 'обед');
      expect(p.lunchAfter, 0);
      expect(p[1]!.lunchInside, isFalse);
      expect(innerBreakWord(p[1]!), 'перерыв');
    });

    test('расписание 3 (суббота): 6 пар по 45 + 45 с перерывом 5 минут', () {
      final p = preset('sat').profile;
      expect(p.slots.length, 6);
      expect(p[7], isNull);
      expect(p[1]!.start, 8 * 60 + 20);
      expect(p[1]!.breakMinutes, 5);
      expect(p[2]!.start, 10 * 60 + 5);
      expect(p[2]!.end, 11 * 60 + 40);
      expect(p[6]!.end, 18 * 60 + 40);
      expect(p.gapAfter(1), 10);
    });

    test('сравнение и сохранение: применённое расписание узнаётся', () {
      final p = preset('week1').profile;
      expect(p.sameAs(BellProfile.fromJson(p.toJson())), isTrue);
      expect(p.sameAs(preset('week2').profile), isFalse);
      expect(p.sameAs(p.withSlot(1, null)), isFalse);
    });
  });

  test('проверка: наложение пар и перерыв вне пары', () {
    final overlap = const BellProfile().withSlot(1, const BellSlot(start: 500, end: 600)).withSlot(2, const BellSlot(start: 590, end: 680));
    expect(overlap.problem, contains('2 пара'));
    const bad = BellSlot(start: 500, end: 590, breakStart: 480, breakEnd: 520);
    expect(bad.valid, isFalse);
    expect(const BellSlot(start: 600, end: 600).valid, isFalse);
  });

  test('какая пара идёт в данную минуту', () {
    final p = generateBells(const BellPlan());
    expect(p.pairAt(8 * 60 + 30), 1);
    expect(p.pairAt(9 * 60 + 59), 1);
    expect(p.pairAt(10 * 60 + 5), isNull); // перерыв
    expect(p.pairAt(10 * 60 + 10), 2);
  });

  test('сохранение и чтение профиля, повреждённые данные не ломают', () {
    final p = generateBells(const BellPlan(lunchAfter: 3, innerBreak: 5));
    final back = BellProfile.fromJson(p.toJson());
    expect(back.slots.length, p.slots.length);
    expect(back.lunchAfter, 3);
    expect(back[2], p[2]);
    expect(BellProfile.fromJson('мусор').isEmpty, isTrue);
    expect(BellProfile.fromJson({'s': {'9': [1, 2], 'x': 5, '1': [100, 50]}}).isEmpty, isTrue);
  });

  group('хранилище', () {
    late AppStore store;
    final day = DateTime(2026, 11, 4);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await AppStore.load();
    });

    test('звонки: будни и суббота не смешиваются', () {
      store.setBellProfile(kBellWeek, generateBells(const BellPlan(firstStart: 8 * 60 + 30)));
      store.setBellProfile(kBellSat, generateBells(const BellPlan(firstStart: 9 * 60)));
      expect(store.bellFor(day, 1)!.start, 8 * 60 + 30);
      expect(store.bellFor(DateTime(2026, 11, 7), 1)!.start, 9 * 60);
      expect(store.bellFor(day, 1)!.start, 8 * 60 + 30);
      expect(store.bellFor(day, 1)!.end, 10 * 60);
    });

    test('старые данные с профилем «short» читаются без ошибок и игнорируют его', () {
      final j = {
        'week': generateBells(const BellPlan()).toJson(),
        'short': generateBells(const BellPlan()).toJson(),
      };
      final settings = Settings.fromJson({'bells': j});
      expect(settings.bells.keys, ['week']);
    });

    test('пометки: на пару и на весь день, даже без расписания, одна на пару', () {
      store.saveMark(DayMark(id: 'a', date: day, lesson: 0, label: 'ОКР'));
      store.saveMark(DayMark(id: 'b', date: day, lesson: 3, label: 'Зачёт'));
      store.saveMark(DayMark(id: 'c', date: day, lesson: 3, label: 'Практика'));
      expect(store.marksOn(day).map((m) => m.label), ['ОКР', 'Практика']);
      expect(store.markFor(day, 3)!.id, 'c');
      final before = store.snapshotMarks(day);
      store.deleteMark('a');
      expect(store.marksOn(day).length, 1);
      store.restoreMarks(day, before);
      expect(store.marksOn(day).length, 2);
    });

    test('пометка «Сокращённый день» — обычная пометка на весь день', () {
      expect(kMarkPresets, contains(kShortDayMark));
      store.saveMark(DayMark(id: 's', date: day, lesson: 0, label: kShortDayMark));
      final m = store.markFor(day, 0)!;
      expect(m.wholeDay, isTrue);
      expect(m.label, 'Сокращённый день');
      store.deleteMark('s');
      expect(store.markFor(day, 0), isNull);
    });

    test('пометки и звонки переживают резервную копию', () {
      store.saveMark(DayMark(id: 'a', date: day, lesson: 0, label: 'Консультация'));
      store.setBellProfile(kBellWeek, generateBells(const BellPlan(lunchAfter: 2)));
      final json = store.exportJson();
      store.deleteMark('a');
      store.setBellProfile(kBellWeek, const BellProfile());
      expect(store.importJson(json), isNull);
      expect(store.marksOn(day).single.label, 'Консультация');
      expect(store.settings.bell(kBellWeek).lunchAfter, 2);
    });

    test('завершение 1-го семестра, отмена и скрытие предупреждений', () {
      final d = DateTime(2026, 12, 20);
      expect(store.semesterOn(d).number, 1);
      expect(store.endFirstSemester(d), isTrue);
      expect(store.semesterOn(d).number, 2);
      expect(store.semesterOn(DateTime(2026, 12, 19)).number, 1);
      expect(store.endFirstSemester(d), isFalse);
      store.reopenFirstSemester(2026);
      expect(store.semesterOn(d).number, 1);

      store.dismissLimit('m:2026-11', 2);
      expect(store.dismissedLevel('m:2026-11'), 2);
      store.dismissLimit('m:2026-12', 2); // новый месяц — прежняя запись стирается
      expect(store.dismissedLevel('m:2026-11'), 0);
      store.dismissLimit('s:2026-1', 1);
      expect(store.dismissedLevel('m:2026-12'), 2);
      store.undoDismissLimit('s:2026-1', 0);
      expect(store.dismissedLevel('s:2026-1'), 0);
    });
  });
}
