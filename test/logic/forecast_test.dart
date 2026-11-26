import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/dates.dart';
import 'package:journal/data/models.dart';
import 'package:journal/logic/forecast.dart';
import 'package:journal/logic/heatmap.dart';

void main() {
  test('склонение количества отметок', () {
    expect([1, 2, 5, 11, 21].map(gradesText).toList(),
      ['1 отметка', '2 отметки', '5 отметок', '11 отметок', '21 отметка']);
  });

  group('прогноз среднего балла', () {
    test('цель уже достигнута', () {
      final f = Forecast.to([8, 9, 8], 8);
      expect(f.reached, isTrue);
      expect(forecastText(f, 8), 'Цель 8 достигнута');
    });

    test('7, 7, 7 до 8: одной отметки мало, нужны две по 10', () {
      // (21 + v) / 4 ≥ 8 → v = 11, нельзя; (21 + 2·v) / 5 ≥ 8 → v = 10
      final f = Forecast.to([7, 7, 7], 8);
      expect(f.reached, isFalse);
      expect(f.count, 2);
      expect(f.value, 10);
      expect(forecastText(f, 8), 'До 8 нужно 2 отметки по 10');
    });

    test('одна отметка достаточна, когда до цели недалеко', () {
      // (28 + 2·v) / 6 ≥ 8 → v ≥ 10; одна отметка: (28+v)/5 ≥ 8 → v = 12, нельзя
      final f = Forecast.to([7, 7, 7, 7], 8);
      expect(f.count, 2);
      expect(f.value, 10);
      final g = Forecast.to([7, 7, 8], 8);
      // сумма 22, n 3: одна отметка: 32 − 22 = 10 → 10
      expect(g.count, 1);
      expect(g.value, 10);
      final h = Forecast.to([7, 8, 8], 8);
      // сумма 23, n 3: одна: 32 − 23 = 9 → 9
      expect(h.count, 1);
      expect(h.value, 9);
      expect(forecastText(h, 8), 'До 8 нужна одна отметка 9');
    });

    test('несколько отметок и склонение', () {
      final f = Forecast.to([5, 5, 5, 5, 5], 8);
      // сумма 25, n 5: k=3: 8·8 − 25 = 39 → 13, нельзя; k=6: 8·11 − 25 = 63 → 10.5 → 11, нельзя
      expect(f.possible, isFalse);
      expect(forecastText(f, 8), 'До 8 не дотянуть за ближайшие отметки');
      final g = Forecast.to([6, 6, 6], 7, maxCount: 6);
      // сумма 18, n 3: k=1: 28 − 18 = 10 → 10
      expect(g.count, 1);
      expect(g.value, 10);
      final h = Forecast.to([6, 6, 6, 6], 7, maxCount: 6);
      // сумма 24, n 4: k=1: 35 − 24 = 11 нельзя; k=2: 42 − 24 = 18 → 9
      expect(h.count, 2);
      expect(h.value, 9);
      expect(forecastText(h, 7), 'До 7 нужно 2 отметки по 9');
    });

    test('без отметок или с неверной целью прогноза нет', () {
      expect(Forecast.to([], 8).possible, isFalse);
      expect(Forecast.to([8], 0).possible, isFalse);
      expect(Forecast.to([8], 11).possible, isFalse);
    });
  });

  group('тепловая карта пропусков', () {
    Absence a(String id, int day, String subject, int hours) =>
        Absence(id: id, date: DateTime(2026, 11, day), lesson: 1, subject: subject, hours: hours);

    test('часы по дням и предметам, чужие месяцы не считаются', () {
      final m = MonthAbsences.of([
        a('1', 3, 'Математика', 2),
        a('2', 3, 'Физика', 1),
        a('3', 10, 'Математика', 2),
        Absence(id: '4', date: DateTime(2026, 10, 3), lesson: 1, subject: 'Физика', hours: 2),
      ], 2026, 11);
      expect(m.hoursByDay, {3: 3, 10: 2});
      expect(m.bySubjectByDay[3], {'Математика': 2, 'Физика': 1});
      expect(m.totalHours, 5);
      expect(m.maxDayHours, 3);
      expect(m.daysInMonth, 30);
    });

    test('насыщенность: самый тяжёлый день 1, пустой 0, любой пропуск не меньше 0,25', () {
      final m = MonthAbsences.of([a('1', 3, 'Математика', 4), a('2', 4, 'Физика', 1)], 2026, 11);
      expect(m.intensity(3), 1);
      expect(m.intensity(5), 0);
      expect(m.intensity(4), greaterThanOrEqualTo(0.25));
      expect(m.intensity(4), lessThan(1));
    });
  });
}
