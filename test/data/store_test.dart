import 'dart:convert';

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

  test('цвет пары сохраняется при перестановке подгрупп, смене дня, перезапуске и восстановлении', () async {
    LessonSlot pair(List<String> names, int n) => LessonSlot(number: n,
      entries: [for (final name in names) LessonEntry(subject: name, room: '$n', teacher: 'Преподаватель $n')]);
    final first = pair(['АнглЯз', 'Физика'], 1);
    final same = pair(['физика', 'Английский   язык'], 4);
    final others = List.generate(40, (i) => pair(['Дисциплина $i'], 3));
    void cache(DateTime date, List<LessonSlot> slots) => store.putSchedule(
      DaySchedule(date: date, group: '6312', slots: slots, fetchedAt: day));
    cache(day, [first]);
    final initial = store.lessonColorId(first);
    cache(day.add(const Duration(days: 7)), [same, ...others]);
    expect(store.lessonColorId(same), initial);
    final ids = others.map(store.lessonColorId).toSet();
    expect(ids, hasLength(40));
    expect(ids, isNot(contains(initial)));
    final backup = store.exportJson();
    store = await AppStore.load();
    expect(store.lessonColorId(same), initial);
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.load();
    expect(store.importJson(backup), isNull);
    expect(store.lessonColorId(same), initial);
    expect(others.map(store.lessonColorId).toSet(), ids);
  });

  test('цвета назначаются расписаниям, сохранённым предыдущей версией', () async {
    final slot = LessonSlot(number: 1, entries: [LessonEntry(subject: 'Математика', room: '', teacher: '')]);
    final legacy = DaySchedule(date: day, group: '6312', slots: [slot], fetchedAt: day);
    SharedPreferences.setMockInitialValues({'sched_v1': jsonEncode([legacy.toJson()])});
    store = await AppStore.load();
    expect(store.lessonColorId(slot), 0);
    expect((store.exportMap()['lessonColors'] as Map).length, 1);
  });

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

  test('неполная или неподдерживаемая копия сохраняет прежние данные', () {
    store.setGroup('43');
    store.saveGrade(Grade(id: 'before', subject: 'Физика', value: 9, date: day));
    final before = store.exportJson();
    for (final broken in [
      {'app': 'journal'},
      {...store.exportMap(), 'version': 99},
      {...store.exportMap(), 'settings': {'group': '12'}, 'tasks': 'ошибка'},
      {...store.exportMap(), 'grades': [{'v': 100}]},
    ]) {
      expect(store.importJson(jsonEncode(broken)), isNotNull);
      expect(store.exportJson(), before);
    }
  });

  test('копия версии 2 восстанавливается без раздела заданий', () {
    final legacy = store.exportMap()..remove('tasks');
    legacy['version'] = 2;
    expect(store.importJson(jsonEncode(legacy)), isNull);
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

  test('задания: сохранение, отметка, привязка к паре и порядок по сроку', () {
    final late = Task(id: 'b', text: 'Сдать реферат', due: DateTime(2026, 11, 5), homework: false);
    final soon = Task(id: 'a', text: 'Параграф 5', due: DateTime(2026, 11, 2), subject: 'Физика', date: day, lesson: 3);
    store.saveTask(late);
    store.saveTask(soon);
    expect(store.openTasks.map((t) => t.id), ['a', 'b']);
    expect(store.tasksForLesson(day, 3).map((t) => t.id), ['a']);
    expect(store.tasksForLesson(day, 2), isEmpty);
    store.toggleTask('a');
    expect(store.openTasks.map((t) => t.id), ['b']);
    store.toggleTask('a');
    expect(store.tasks.firstWhere((t) => t.id == 'a').done, isFalse);
    store.saveTask(late.copyWith(text: 'Сдать реферат по физике'));
    expect(store.tasks.length, 2);
    expect(store.tasks.firstWhere((t) => t.id == 'b').text, 'Сдать реферат по физике');
    store.deleteTask('b');
    expect(store.tasks.length, 1);
  });

  test('цели по предметам: установка, замена и снятие', () {
    store.setGoal('Физика', 8);
    expect(store.settings.goals['Физика'], 8);
    store.setGoal('Физика', 9);
    expect(store.settings.goals['Физика'], 9);
    store.setGoal('Физика', null);
    expect(store.settings.goals.containsKey('Физика'), isFalse);
    store.setGoal('Физика', 11);
    expect(store.settings.goals, isEmpty);
  });

  test('порядок блоков главной: перестановка и скрытие нормализуются', () {
    store.setHomeLayout([kBlockRecent, 'мусор', kBlockRecent], [kBlockWeek, 'мусор']);
    expect(store.settings.homeOrder.first, kBlockRecent);
    expect(store.settings.homeOrder.toSet().length, kHomeBlocks.length);
    expect(store.settings.homeHidden, [kBlockWeek]);
  });

  test('копия содержит задания, цели и порядок блоков', () {
    store.saveTask(Task(id: 't', text: 'Принести тетрадь', due: DateTime(2026, 11, 3)));
    store.setGoal('Физика', 8);
    store.setHomeLayout([kBlockRecent], [kBlockWeek]);
    final json = store.exportJson();
    store.deleteTask('t');
    store.setGoal('Физика', null);
    store.setHomeLayout(kHomeBlocks, const []);
    expect(store.importJson(json), isNull);
    expect(store.tasks.single.text, 'Принести тетрадь');
    expect(store.settings.goals['Физика'], 8);
    expect(store.settings.homeOrder.first, kBlockRecent);
    expect(store.settings.homeHidden, [kBlockWeek]);
  });
}
