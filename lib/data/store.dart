import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dates.dart';
import '../logic/subject_names.dart';
import 'models.dart';

/// Всё состояние приложения + сохранение на устройстве.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);
  final SharedPreferences _prefs;

  static const _kData = 'data_v1';
  static const _kSched = 'sched_v1';
  static const _kBackupId = 'journal';
  // Резервные копии, сделанные до переименования приложения, по-прежнему читаются.
  static const _kLegacyBackupId = 'mgtek_college';
  static const maxCached = 400;

  Settings settings = Settings();
  List<Grade> grades = [];
  List<Absence> absences = [];
  final Map<String, DaySchedule> _cache = {}; // 'группа|yyyy-MM-dd'
  bool get hasGroup => settings.group.isNotEmpty;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppStore._(prefs);
    s._readData();
    s._readCache();
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

  void _applyBackup(Object? decoded) {
    final j = Map<String, dynamic>.from(decoded as Map);
    settings = Settings.fromJson(j['settings']);
    grades = ((j['grades'] as List?) ?? const []).map(Grade.tryFromJson).whereType<Grade>().toList();
    absences =
        ((j['absences'] as List?) ?? const []).map(Absence.tryFromJson).whereType<Absence>().toList();
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
        'version': 1,
        'settings': settings.toJson(),
        'grades': grades.map((g) => g.toJson()).toList(),
        'absences': absences.map((a) => a.toJson()).toList(),
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
      if (decoded is! Map || (decoded['app'] != _kBackupId && decoded['app'] != _kLegacyBackupId)) {
        return 'Это не резервная копия приложения';
      }
      _applyBackup(decoded);
      _changed();
      return null;
    } catch (_) {
      return 'Не удалось прочитать данные. Проверьте, что скопирован весь текст.';
    }
  }
}
