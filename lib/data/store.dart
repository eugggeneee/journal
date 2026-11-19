import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dates.dart';
import '../logic/bells.dart';
import '../logic/limits.dart';
import '../logic/subject_names.dart';
import 'models.dart';

/// Всё состояние приложения + сохранение на устройстве.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);
  final SharedPreferences _prefs;

  static const _kData = 'data_v1';
  static const _kSched = 'sched_v1';
  static const _kBackupId = 'journal';
  static const maxCached = 400;

  Settings settings = Settings();
  List<Grade> grades = [];
  List<Absence> absences = [];
  List<DayMark> marks = [];
  List<Task> tasks = [];
  final Map<String, DaySchedule> _cache = {}; // 'группа|yyyy-MM-dd'
  final Map<String, int> _lessonColors = {};
  bool get hasGroup => settings.group.isNotEmpty;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppStore._(prefs);
    s._readData();
    s._readCache();
    if (s._registerLessonColors(s._cache.values)) s._saveData();
    return s;
  }

  // ───────────────────────── чтение ─────────────────────────

  void _readData() {
    final raw = _prefs.getString(_kData);
    if (raw == null) return;
    try {
      _applyBackup(jsonDecode(raw));
    } catch (_) {
      // повреждённые данные не должны ронять приложение
    }
  }

  void _applyBackup(Object? decoded, {bool strict = false}) {
    final j = Map<String, dynamic>.from(decoded as Map);
    List<T> records<T>(String key, T? Function(Object?) parse) {
      final raw = (j[key] as List?) ?? const [];
      final result = raw.map(parse).whereType<T>().toList();
      if (strict && result.length != raw.length) throw FormatException(key);
      return result;
    }

    // Сначала разбираем всю копию: ошибка в последнем разделе не меняет предыдущие.
    final restoredSettings = Settings.fromJson(j['settings'], strict: strict);
    final restoredGrades = records('grades', Grade.tryFromJson);
    final restoredAbsences = records('absences', Absence.tryFromJson);
    final restoredMarks = records('marks', DayMark.tryFromJson);
    final restoredTasks = records('tasks', Task.tryFromJson);
    final rawColors = j['lessonColors'];
    final restoredColors = <String, int>{};
    final used = <int>{};
    if (rawColors is Map) {
      for (final entry in rawColors.entries) {
        final id = entry.value;
        if (entry.key is String && id is int && id >= 0 && id <= 0x7fffffff && used.add(id)) {
          restoredColors[entry.key as String] = id;
        }
      }
    }
    if (rawColors is Map) {
      _lessonColors..clear()..addAll(restoredColors);
    }
    settings = restoredSettings;
    grades = restoredGrades;
    absences = restoredAbsences;
    marks = restoredMarks;
    tasks = restoredTasks;
  }

  void _readCache() {
    final raw = _prefs.getString(_kSched);
    if (raw == null) return;
    try {
      for (final e in (jsonDecode(raw) as List)) {
        final s = DaySchedule.tryFromJson(e);
        if (s != null) _cache['${s.group}|${ymd(s.date)}'] = s;
      }
    } catch (_) {}
  }

  // ───────────────────────── запись ─────────────────────────

  Map<String, dynamic> exportMap() => {
        'app': _kBackupId,
        'version': 3,
        'settings': settings.toJson(),
        'grades': grades.map((g) => g.toJson()).toList(),
        'absences': absences.map((a) => a.toJson()).toList(),
        'marks': marks.map((m) => m.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'lessonColors': Map<String, int>.of(_lessonColors),
      };

  void _saveData() => _prefs.setString(_kData, jsonEncode(exportMap()));

  void _saveCache() =>
      _prefs.setString(_kSched, jsonEncode(_cache.values.map((s) => s.toJson()).toList()));

  void _changed() {
    _saveData();
    notifyListeners();
  }

  // ───────────────────────── кэш расписания ─────────────────────────

  DaySchedule? cachedSchedule(String group, DateTime date) => _cache['$group|${ymd(date)}'];

  Iterable<DaySchedule> schedulesFor(String group) => _cache.values.where((s) => s.group == group);

  void putSchedule(DaySchedule s) {
    _cache['${s.group}|${ymd(s.date)}'] = s;
    if (_cache.length > maxCached) {
      final entries = _cache.entries.toList()..sort((a, b) => a.value.date.compareTo(b.value.date));
      for (var i = 0; i < _cache.length - maxCached; i++) {
        _cache.remove(entries[i].key);
      }
    }
    if (_registerLessonColors([s])) _saveData();
    _saveCache();
    notifyListeners();
  }

  // ───────────────────────── оценки ─────────────────────────

  void saveGrade(Grade g) {
    final i = grades.indexWhere((x) => x.id == g.id);
    if (i >= 0) {
      grades[i] = g;
    } else {
      grades.add(g);
    }
    _changed();
  }

  void deleteGrade(String id) {
    grades.removeWhere((g) => g.id == id);
    _changed();
  }

  List<Grade> gradesOf(String subject) => grades.where((g) => g.subject == subject).toList();

  /// Предмет последней по дате оценки — удобная подсказка при добавлении новой.
  String? get lastGradeSubject {
    if (grades.isEmpty) return null;
    final sorted = [...grades]..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return sorted.last.subject;
  }

  // ───────────────────────── задания ─────────────────────────

  void saveTask(Task t) {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    _changed();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _changed();
  }

  void toggleTask(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    tasks[i] = tasks[i].copyWith(done: !tasks[i].done);
    _changed();
  }

  /// Задания, привязанные к паре.
  List<Task> tasksForLesson(DateTime date, int lesson) =>
      tasks.where((t) => t.lesson == lesson && t.date != null && sameDay(t.date!, date)).toList();

  /// Невыполненные задания по сроку: просроченные идут первыми.
  List<Task> get openTasks {
    final list = tasks.where((t) => !t.done).toList()
      ..sort((a, b) {
        final c = a.due.compareTo(b.due);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return list;
  }

  // ───────────────────────── пропуски ─────────────────────────

  /// Один пропуск на пару в день: повторное добавление заменяет предыдущий.
  void _putAbsence(Absence a) {
    if (a.lesson > 0) {
      absences.removeWhere((x) => x.id != a.id && x.lesson == a.lesson && sameDay(x.date, a.date));
    }
    final i = absences.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      absences[i] = a;
    } else {
      absences.add(a);
    }
  }

  void saveAbsence(Absence a) {
    _putAbsence(a);
    _changed();
  }

  /// Сохраняет сразу несколько пропусков (одним обновлением интерфейса).
  void saveAbsences(Iterable<Absence> list) {
    for (final a in list) {
      _putAbsence(a);
    }
    _changed();
  }

  void deleteAbsence(String id) {
    absences.removeWhere((a) => a.id == id);
    _changed();
  }

  /// Удаляет пропуски дня; если [lessons] задан — только эти пары.
  void clearAbsencesOn(DateTime date, {Set<int>? lessons}) {
    absences.removeWhere((a) => sameDay(a.date, date) && (lessons == null || lessons.contains(a.lesson)));
    _changed();
  }

  /// Снимок дня и его восстановление — основа для «Отменить» в любой операции с пропусками.
  List<Absence> snapshotDay(DateTime date) => absencesOn(date);

  void restoreDay(DateTime date, List<Absence> snapshot) {
    absences.removeWhere((a) => sameDay(a.date, date));
    absences.addAll(snapshot);
    _changed();
  }

  Absence? absenceFor(DateTime date, int lesson) {
    if (lesson <= 0) return null;
    for (final a in absences) {
      if (a.lesson == lesson && sameDay(a.date, date)) return a;
    }
    return null;
  }

  List<Absence> absencesOn(DateTime date) => absences.where((a) => sameDay(a.date, date)).toList();


  // ───────────────────────── пометки к дате ─────────────────────────

  /// Одна пометка на пару (или на весь день) в день: новая заменяет прежнюю.
  void _putMark(DayMark m) {
    marks.removeWhere((x) => x.id != m.id && x.lesson == m.lesson && sameDay(x.date, m.date));
    final i = marks.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      marks[i] = m;
    } else {
      marks.add(m);
    }
  }

  void saveMark(DayMark m) {
    _putMark(m);
    _changed();
  }

  void deleteMark(String id) {
    marks.removeWhere((m) => m.id == id);
    _changed();
  }

  List<DayMark> marksOn(DateTime date) {
    final list = marks.where((m) => sameDay(m.date, date)).toList()..sort((a, b) => a.lesson.compareTo(b.lesson));
    return list;
  }

  DayMark? markFor(DateTime date, int lesson) {
    for (final m in marks) {
      if (m.lesson == lesson && sameDay(m.date, date)) return m;
    }
    return null;
  }

  /// Снимок пометок дня и его восстановление — для «Отменить».
  List<DayMark> snapshotMarks(DateTime date) => marksOn(date);

  void restoreMarks(DateTime date, List<DayMark> snapshot) {
    marks.removeWhere((m) => sameDay(m.date, date));
    marks.addAll(snapshot);
    _changed();
  }

  // ───────────────────────── звонки ─────────────────────────

  /// Какие звонки действуют в этот день: день с пометкой «Сокращённый день» идёт по своему расписанию звонков,
  /// остальные дни по будням или субботе. Пометку достаточно поставить, звонки подставятся сами.
  String bellKeyOn(DateTime date) => markFor(date, 0)?.label == kShortDayMark ? kBellShort : bellKeyFor(date);

  /// Расписание звонков, действующее в этот день.
  BellProfile bellProfileFor(DateTime date) => settings.bell(bellKeyOn(date));

  /// Время конкретной пары в этот день (null — не задано).
  BellSlot? bellFor(DateTime date, int lesson) => bellProfileFor(date)[lesson];

  void setBellProfile(String key, BellProfile profile) {
    if (!kBellKeys.contains(key)) return;
    if (profile.isEmpty && profile.lunchAfter == 0) {
      settings.bells.remove(key);
    } else {
      settings.bells[key] = profile;
    }
    _changed();
  }

  // ───────────────────────── лимиты и семестры ─────────────────────────

  /// Текущий семестр (на сегодня или на указанную дату).
  Semester semesterOn([DateTime? now]) => semesterFor(now ?? DateTime.now(), settings.semesterSplits);

  /// Завершает 1-й семестр: со дня [from] идёт 2-й, до 1 августа.
  bool endFirstSemester(DateTime from) {
    final now = dateOnly(from);
    if (!canEndSemester(now, settings.semesterSplits)) return false;
    final sem = semesterFor(now, settings.semesterSplits);
    settings.semesterSplits['${sem.year}'] = ymd(now);
    _changed();
    return true;
  }

  /// Возвращает 1-й семестр (отмена завершения) в указанном учебном году.
  void reopenFirstSemester(int year) {
    if (settings.semesterSplits.remove('$year') != null) _changed();
  }

  int dismissedLevel(String key) => settings.dismissed[key] ?? 0;

  /// Скрывает предупреждение периода [key] до уровня [level] включительно.
  /// Записи о прошлых периодах стираются — месяц или семестр сменился, счётчик начинается заново.
  void dismissLimit(String key, int level) {
    final kind = key.substring(0, 2);
    settings.dismissed.removeWhere((k, _) => k.startsWith(kind) && k != key);
    if ((settings.dismissed[key] ?? 0) >= level) return;
    settings.dismissed[key] = level;
    _changed();
  }

  void undoDismissLimit(String key, int previous) {
    if (previous <= 0) {
      settings.dismissed.remove(key);
    } else {
      settings.dismissed[key] = previous;
    }
    _changed();
  }

  // ───────────────────────── настройки ─────────────────────────

  void setGroup(String group) {
    final g = group.trim();
    if (g.isEmpty || g == settings.group) return;
    settings.group = g;
    _changed();
  }

  bool get onboarded => settings.onboarded;

  void finishOnboarding() {
    if (settings.onboarded) return;
    settings.onboarded = true;
    _changed();
  }

  void setThemeMode(int v) {
    if (v == settings.themeMode || v < 0 || v > 2) return;
    settings.themeMode = v;
    _changed();
  }

  /// Цветовая тема: 'auto' (по системе) или id из палитры приложения.
  void setThemeColor(String id) {
    final v = id.trim();
    if (v.isEmpty || v == settings.themeColor) return;
    settings.themeColor = v;
    _changed();
  }

  void setAbsenceHours(int v) {
    final h = v == 1 ? 1 : 2;
    if (h == settings.absenceHours) return;
    settings.absenceHours = h;
    _changed();
  }

  void setHaptics(bool v) {
    if (v == settings.haptics) return;
    settings.haptics = v;
    _changed();
  }

  /// Анимации: 0 — выразительные, 1 — спокойные, 2 — выключены.
  void setMotion(int v) {
    if (v == settings.motion || v < 0 || v > 2) return;
    settings.motion = v;
    _changed();
  }

  void setDayCardFolded(bool v) {
    if (v == settings.dayCardFolded) return;
    settings.dayCardFolded = v;
    _changed();
  }

  void setWeekView(bool v) {
    if (v == settings.weekView) return;
    settings.weekView = v;
    _changed();
  }

  void setTipGestures(bool v) {
    if (v == settings.tipGestures) return;
    settings.tipGestures = v;
    _changed();
  }

  /// Цель по предмету (1…10); null снимает цель.
  void setGoal(String subject, int? goal) {
    if (goal == null || goal < 1 || goal > 10) {
      if (settings.goals.remove(subject) == null) return;
    } else {
      if (settings.goals[subject] == goal) return;
      settings.goals[subject] = goal;
    }
    _changed();
  }

  /// Порядок и видимость блоков главной.
  void setHomeLayout(List<String> order, List<String> hidden) {
    settings.homeOrder = normalizeHomeOrder(order);
    settings.homeHidden = hidden.where(kHomeBlocks.contains).toSet().toList();
    _changed();
  }

  void setAutoRefresh(bool v) {
    if (v == settings.autoRefresh) return;
    settings.autoRefresh = v;
    _changed();
  }

  void addExtraSubject(String name) {
    final n = name.trim();
    if (n.isEmpty || settings.extraSubjects.contains(n)) return;
    settings.extraSubjects.add(n);
    _changed();
  }

  // ───────────────────────── предметы ─────────────────────────

  String subjectName(String key) => builtinSubjectNames[key] ?? key;

  // Отображаемое полное название объединяет известные варианты сокращений колледжа.
  // Порядок подгрупп, кабинет и время занятия на идентификатор не влияют.
  String _lessonKey(LessonSlot slot) {
    final names = slot.subjects
        .map((s) => subjectName(s.trim()).toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()..sort();
    return jsonEncode(names);
  }

  bool _registerLessonColors(Iterable<DaySchedule> schedules) {
    final keys = {for (final day in schedules) for (final slot in day.slots) _lessonKey(slot)}
      ..removeAll(_lessonColors.keys);
    if (keys.isEmpty) return false;
    final used = _lessonColors.values.toSet();
    var id = 0;
    for (final key in keys.toList()..sort()) {
      while (used.contains(id)) {
        id++;
      }
      _lessonColors[key] = id++;
    }
    return true;
  }

  int lessonColorId(LessonSlot slot) {
    final key = _lessonKey(slot);
    final saved = _lessonColors[key];
    if (saved != null) return saved;
    // Предпросмотр или незакэшированный день: не записываем настройки во время build.
    return key.codeUnits.fold<int>(0, (h, u) => (31 * h + u) & 0x7fffffff);
  }

  /// Все известные предметы: из расписания, оценок, пропусков и добавленные вручную.
  List<String> knownSubjects() {
    final set = <String>{};
    for (final s in schedulesFor(settings.group)) {
      for (final slot in s.slots) {
        for (final e in slot.entries) {
          set.add(e.subject);
        }
      }
    }
    for (final g in grades) {
      if (g.subject.isNotEmpty) set.add(g.subject);
    }
    for (final a in absences) {
      if (a.subject.isNotEmpty) set.add(a.subject);
    }
    set.addAll(settings.extraSubjects);
    final list = set.toList()..sort((a, b) => subjectName(a).compareTo(subjectName(b)));
    return list;
  }

  // ───────────────────────── резервная копия ─────────────────────────

  String exportJson() => const JsonEncoder.withIndent('  ').convert(exportMap());

  /// Возвращает текст ошибки или null, если всё прошло успешно.
  String? importJson(String text) {
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is! Map || (decoded['app'] != _kBackupId)) {
        return 'Это не резервная копия приложения';
      }
      final version = decoded['version'];
      if (version is! int || version < 1 || version > 3) return 'Неподдерживаемая версия резервной копии';
      final requiredLists = ['grades', 'absences', if (version >= 2) 'marks', if (version >= 3) 'tasks'];
      if (decoded['settings'] is! Map || requiredLists.any((key) => decoded[key] is! List)) {
        return 'В резервной копии отсутствуют данные';
      }
      _applyBackup(decoded, strict: true);
      _registerLessonColors(_cache.values);
      _changed();
      return null;
    } catch (_) {
      return 'Не удалось прочитать данные. Проверьте, что скопирован весь текст.';
    }
  }
}
