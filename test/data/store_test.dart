import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';
import 'package:journal/data/store.dart';
import 'package:journal/logic/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore store;
  final day = DateTime(2026, 10, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.load();
  });

  Absence abs(int lesson, {int hours = 2}) =>
      Absence(id: newId(), date: day, lesson: lesson, subject: 'S$lesson', hours: hours);

  test('повторный пропуск той же пары заменяет прежний', () {
    store.saveAbsence(abs(1));
    store.saveAbsence(abs(1, hours: 1));
    expect(store.absences.length, 1);
    expect(store.absenceFor(day, 1)!.hours, 1);
  });

  test('весь день одним действием и отмена через снимок', () {
    final before = store.snapshotDay(day);
    store.saveAbsences([abs(1), abs(2), abs(3)]);
    expect(store.absencesOn(day).length, 3);
    store.restoreDay(day, before);
    expect(store.absences, isEmpty);
  });

  test('снятие отметок только у выбранных пар', () {
    store.saveAbsences([abs(1), abs(2)]);
    store.clearAbsencesOn(day, lessons: {1});
    expect(store.absences.map((a) => a.lesson), [2]);
  });

  test('оценки: сохранение, статистика и влияние последней', () {
    store.saveGrade(Grade(id: 'a', subject: 'M', value: 6, date: DateTime(2026, 10, 1)));
    store.saveGrade(Grade(id: 'b', subject: 'M', value: 10, date: DateTime(2026, 10, 2)));
    final st = GradeStats.of(store.grades);
    expect(st.average, 8);
    expect(st.distribution[9], 1);
    expect(st.subjects.single.lastImpact, 2);
    expect(store.lastGradeSubject, 'M');
  });

  test('пропуски: часы, число записей и последняя дата по предметам', () {
    store.saveAbsences([
      Absence(id: 'x1', date: DateTime(2026, 10, 28), lesson: 1, subject: 'M', hours: 2),
      Absence(id: 'x2', date: DateTime(2026, 10, 30), lesson: 2, subject: 'M', hours: 1, excused: true),
      Absence(id: 'x3', date: DateTime(2026, 10, 29), lesson: 3, subject: 'P', hours: 2),
    ]);
    final st = AbsenceStats.of(store.absences);
    expect(st.totalHours, 5);
    expect(st.excusedHours, 1);
    expect(st.unexcusedHours, 4);
    expect(st.bySubjectHours['M'], 3);
    expect(st.bySubjectCount['M'], 2);
    expect(st.bySubjectCount['P'], 1);
    expect(st.lastBySubject['M'], DateTime(2026, 10, 30));
    expect(st.lastBySubject['P'], DateTime(2026, 10, 29));
  });

  test('резервная копия переживает экспорт и импорт', () {
    store.saveGrade(Grade(id: 'a', subject: 'M', value: 7, date: day));
    store.saveAbsence(abs(2));
    final json = store.exportJson();
    store.deleteGrade('a');
    store.deleteAbsence(store.absences.first.id);
    expect(store.importJson(json), isNull);
    expect(store.grades.length, 1);
    expect(store.absences.length, 1);
  });
}
