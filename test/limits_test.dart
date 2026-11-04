import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';
import 'package:journal/logic/limits.dart';

void main() {
  Absence a(DateTime d, int hours, {bool excused = false, int lesson = 1}) =>
      Absence(id: newId(), date: d, lesson: lesson, subject: 'S', hours: hours, excused: excused);

  group('месячный счётчик', () {
    final list = [
      a(DateTime(2026, 10, 31), 2),
      a(DateTime(2026, 11, 1), 2),
      a(DateTime(2026, 11, 20), 4, excused: true),
      a(DateTime(2026, 11, 30), 1, lesson: 2),
      a(DateTime(2026, 12, 1), 2),
    ];

    test('считает только неуважительные в календарном месяце, с 1-го по последнее число', () {
      expect(monthUnexcusedHours(list, DateTime(2026, 11, 4)), 3);
      expect(monthUnexcusedHours(list, DateTime(2026, 10, 15)), 2);
    });

    test('с нового месяца счётчик начинается с нуля', () {
      expect(monthUnexcusedHours(list, DateTime(2026, 11, 30)), 3);
      expect(monthUnexcusedHours(list, DateTime(2027, 1, 1)), 0);
    });

    test('уровни: 7 — близко, 10 — лимит', () {
      LimitLevel l(int h) => limitLevel(h, warnFrom: kMonthWarnFrom, limit: kMonthLimit);
      expect(l(6), LimitLevel.ok);
      expect(l(7), LimitLevel.near);
      expect(l(9), LimitLevel.near);
      expect(l(10), LimitLevel.reached);
      expect(l(14), LimitLevel.reached);
    });
  });

  group('семестры', () {
    test('1-й семестр идёт с 1 сентября, пока не нажата кнопка', () {
      final s = semesterFor(DateTime(2026, 11, 4), {});
      expect(s.number, 1);
      expect(s.year, 2026);
      expect(s.start, DateTime(2026, 9, 1));
      expect(s.end, DateTime(2027, 8, 1));
      expect(s.upcoming, isFalse);
    });

    test('после нажатия сразу идёт 2-й семестр до 1 августа', () {
      final splits = {'2026': '2027-01-24'};
      expect(semesterFor(DateTime(2027, 1, 23), splits).number, 1);
      expect(semesterFor(DateTime(2027, 1, 23), splits).end, DateTime(2027, 1, 23));
      final s2 = semesterFor(DateTime(2027, 1, 24), splits);
      expect(s2.number, 2);
      expect(s2.start, DateTime(2027, 1, 24));
      expect(s2.end, DateTime(2027, 8, 1));
      expect(semesterFor(DateTime(2027, 8, 1), splits).number, 2);
    });

    test('со 2 по 31 августа — каникулы, показан будущий 1-й семестр', () {
      final s = semesterFor(DateTime(2027, 8, 15), {'2026': '2027-01-24'});
      expect(s.upcoming, isTrue);
      expect(s.number, 1);
      expect(s.year, 2027);
      expect(canEndSemester(DateTime(2027, 8, 15), {}), isFalse);
      expect(semesterFor(DateTime(2027, 9, 1), {}).upcoming, isFalse);
    });

    test('январь–июль относятся к учебному году, начавшемуся в прошлом сентябре', () {
      expect(academicYearOf(DateTime(2027, 3, 3)), 2026);
      expect(academicYearOf(DateTime(2027, 8, 1)), 2026);
      expect(academicYearOf(DateTime(2027, 9, 1)), 2027);
    });

    test('завершить можно только 1-й семестр', () {
      expect(canEndSemester(DateTime(2026, 11, 4), {}), isTrue);
      expect(canEndSemester(DateTime(2027, 2, 1), {'2026': '2027-01-24'}), isFalse);
    });

    test('часы семестра считаются по его границам', () {
      final splits = {'2026': '2027-01-24'};
      final list = [
        a(DateTime(2026, 8, 31), 2),
        a(DateTime(2026, 9, 1), 2),
        a(DateTime(2027, 1, 23), 4),
        a(DateTime(2027, 1, 24), 2),
        a(DateTime(2027, 2, 1), 2, excused: true),
        a(DateTime(2027, 5, 1), 1, lesson: 2),
      ];
      final now1 = semesterFor(DateTime(2027, 1, 10), splits);
      final now2 = semesterFor(DateTime(2027, 5, 2), splits);
      expect(semesterUnexcusedHours(list, now1), 6);
      expect(semesterUnexcusedHours(list, now2), 3);
    });

    test('предупреждение семестра с 62 часов, лимит 72', () {
      LimitLevel l(int h) => limitLevel(h, warnFrom: kSemesterWarnFrom, limit: kSemesterLimit);
      expect(l(61), LimitLevel.ok);
      expect(l(62), LimitLevel.near);
      expect(l(71), LimitLevel.near);
      expect(l(72), LimitLevel.reached);
    });
  });
}
