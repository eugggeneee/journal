import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';
import 'package:journal/data/store.dart';
import 'package:journal/logic/bells.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('профиль звонков: суббота и сокращённый день выбираются отдельно', () {
    expect(bellKeyFor(DateTime(2026, 11, 4), shortDay: false), kBellWeek);
    expect(bellKeyFor(DateTime(2026, 11, 7), shortDay: false), kBellSat);
    expect(bellKeyFor(DateTime(2026, 11, 7), shortDay: true), kBellShort);
    expect(bellKeyFor(DateTime(2026, 11, 4), shortDay: true), kBellShort);
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

    test('звонки: будни, суббота и сокращённый день не смешиваются', () {
      store.setBellProfile(kBellWeek, generateBells(const BellPlan(firstStart: 8 * 60 + 30)));
      store.setBellProfile(kBellSat, generateBells(const BellPlan(firstStart: 9 * 60)));
      expect(store.bellFor(day, 1)!.start, 8 * 60 + 30);
      expect(store.bellFor(DateTime(2026, 11, 7), 1)!.start, 9 * 60);
      expect(store.bellFor(day, 1)!.start, 8 * 60 + 30);
      store.setBellProfile(kBellShort, generateBells(const BellPlan(firstStart: 8 * 60, pairMinutes: 60)));
      expect(store.bellFor(day, 1)!.start, 8 * 60 + 30);
      store.setShortDay(day, true);
      expect(store.bellFor(day, 1)!.end, 9 * 60);
      store.setShortDay(day, false);
      expect(store.bellFor(day, 1)!.end, 10 * 60);
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

    test('пометки, сокращённые дни и звонки переживают резервную копию', () {
      store.saveMark(DayMark(id: 'a', date: day, lesson: 0, label: 'Консультация'));
      store.setShortDay(day, true);
      store.setBellProfile(kBellWeek, generateBells(const BellPlan(lunchAfter: 2)));
      final json = store.exportJson();
      store.deleteMark('a');
      store.setShortDay(day, false);
      store.setBellProfile(kBellWeek, const BellProfile());
      expect(store.importJson(json), isNull);
      expect(store.marksOn(day).single.label, 'Консультация');
      expect(store.isShortDay(day), isTrue);
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
