import '../core/dates.dart';

int _int(Object? v, int fallback) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);
String _str(Object? v) => v == null ? '' : '$v';

/// Одна строка расписания: предмет + аудитория + преподаватель.
class LessonEntry {
  const LessonEntry({required this.subject, required this.room, required this.teacher});
  final String subject;
  final String room;
  final String teacher;

  Map<String, dynamic> toJson() => {'s': subject, 'r': room, 't': teacher};
  factory LessonEntry.fromJson(Map<String, dynamic> j) =>
      LessonEntry(subject: _str(j['s']), room: _str(j['r']), teacher: _str(j['t']));

  @override
  bool operator ==(Object other) =>
      other is LessonEntry &&
      other.subject == subject &&
      other.room == room &&
      other.teacher == teacher;
  @override
  int get hashCode => Object.hash(subject, room, teacher);
}

/// Пара №N. Несколько entries — подгруппы (разные аудитории/преподаватели).
class LessonSlot {
  const LessonSlot({required this.number, required this.entries});
  final int number;
  final List<LessonEntry> entries;

  String get subject => entries.first.subject;
  List<String> get subjects {
    final out = <String>[];
    for (final e in entries) {
      if (!out.contains(e.subject)) out.add(e.subject);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {'n': number, 'e': entries.map((e) => e.toJson()).toList()};
  factory LessonSlot.fromJson(Map<String, dynamic> j) => LessonSlot(
        number: _int(j['n'], 0),
        entries: ((j['e'] as List?) ?? const [])
            .map((e) => LessonEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Расписание группы на один день.
class DaySchedule {
  const DaySchedule({
    required this.date,
    required this.group,
    required this.slots,
    required this.fetchedAt,
  });
  final DateTime date;
  final String group;
  final List<LessonSlot> slots;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
        'd': ymd(date),
        'g': group,
        'f': fetchedAt.millisecondsSinceEpoch,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  static DaySchedule? tryFromJson(Object? raw) {
    try {
      final j = Map<String, dynamic>.from(raw as Map);
      final d = parseYmd(_str(j['d']));
      if (d == null) return null;
      return DaySchedule(
        date: d,
        group: _str(j['g']),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(_int(j['f'], 0)),
        slots: ((j['slots'] as List?) ?? const [])
            .map((e) => LessonSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Оценка (белорусская 10-балльная шкала).
class Grade {
  Grade({
    required this.id,
    required this.subject,
    required this.value,
    required this.date,
    this.kind = '',
    this.note = '',
  });
  final String id;
  final String subject; // ключ предмета (как на сайте)
  final int value; // 1..10
  final DateTime date;
  final String kind; // тип работы (ответ, контрольная, ...)
  final String note;

  Grade copyWith({String? subject, int? value, DateTime? date, String? kind, String? note}) => Grade(
        id: id,
        subject: subject ?? this.subject,
        value: value ?? this.value,
        date: date ?? this.date,
        kind: kind ?? this.kind,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        's': subject,
        'v': value,
        'd': ymd(date),
        'k': kind,
        'n': note,
      };

  static Grade? tryFromJson(Object? raw) {
    try {
      final j = Map<String, dynamic>.from(raw as Map);
      final d = parseYmd(_str(j['d']));
      final v = _int(j['v'], 0);
      if (d == null || v < 1 || v > 10) return null;
      return Grade(
        id: _str(j['id']).isEmpty ? newId() : _str(j['id']),
        subject: _str(j['s']),
        value: v,
        date: d,
        kind: _str(j['k']),
        note: _str(j['n']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Пропуск: 1 или 2 часа (пара = 2 академических часа).
class Absence {
  Absence({
    required this.id,
    required this.date,
    required this.lesson,
    required this.subject,
    required this.hours,
    this.excused = false,
    this.note = '',
  });
  final String id;
  final DateTime date;
  final int lesson; // номер пары, 0 — не указан
  final String subject;
  final int hours; // 1 или 2
  final bool excused; // по уважительной причине
  final String note;

  Absence copyWith({
    DateTime? date,
    int? lesson,
    String? subject,
    int? hours,
    bool? excused,
    String? note,
  }) =>
      Absence(
        id: id,
        date: date ?? this.date,
        lesson: lesson ?? this.lesson,
        subject: subject ?? this.subject,
        hours: hours ?? this.hours,
        excused: excused ?? this.excused,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'd': ymd(date),
        'l': lesson,
        's': subject,
        'h': hours,
        'e': excused,
        'n': note,
      };

  static Absence? tryFromJson(Object? raw) {
    try {
      final j = Map<String, dynamic>.from(raw as Map);
      final d = parseYmd(_str(j['d']));
      final h = _int(j['h'], 2);
      if (d == null) return null;
      return Absence(
        id: _str(j['id']).isEmpty ? newId() : _str(j['id']),
        date: d,
        lesson: _int(j['l'], 0),
        subject: _str(j['s']),
        hours: h == 1 ? 1 : 2,
        excused: j['e'] == true,
        note: _str(j['n']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Настройки приложения. Часть из них выбирается на приветственных экранах.
class Settings {
  Settings({
    this.group = '',
    List<String>? extraSubjects,
    this.onboarded = false,
    this.themeMode = 0,
    this.themeColor = 'auto',
    this.absenceHours = 2,
    this.haptics = true,
    this.autoRefresh = true,
  }) : extraSubjects = extraSubjects ?? [];

  String group; // пусто — группа ещё не выбрана
  final List<String> extraSubjects; // предметы, добавленные вручную

  bool onboarded; // приветственные экраны уже пройдены
  int themeMode; // 0 — как в системе, 1 — светлая, 2 — тёмная
  String themeColor; // цветовая тема: 'auto' — подстраивается под систему (Material You), либо id из палитры
  int absenceHours; // сколько часов отмечать при быстром нажатии: 1 или 2
  bool haptics; // тактильная отдача
  bool autoRefresh; // подгружать расписание при запуске и возвращении в приложение

  Map<String, dynamic> toJson() => {
        'group': group,
        'extra': extraSubjects,
        'onb': onboarded,
        'theme': themeMode,
        'tc': themeColor,
        'ah': absenceHours,
        'hap': haptics,
        'auto': autoRefresh,
      };

  factory Settings.fromJson(Object? raw) {
    try {
      final j = Map<String, dynamic>.from(raw as Map);
      final group = _str(j['group']).trim();
      final theme = _int(j['theme'], 0);
      final color = _str(j['tc']).trim();
      final hours = _int(j['ah'], 2);
      return Settings(
        group: group,
        extraSubjects: ((j['extra'] as List?) ?? const []).map(_str).toList(),
        // копии и данные из прошлых версий: если группа уже выбрана — приветствие не показываем
        onboarded: j['onb'] is bool ? j['onb'] as bool : group.isNotEmpty,
        themeMode: theme >= 0 && theme <= 2 ? theme : 0,
        themeColor: color.isEmpty ? 'auto' : color,
        absenceHours: hours == 1 ? 1 : 2,
        haptics: j['hap'] is bool ? j['hap'] as bool : true,
        autoRefresh: j['auto'] is bool ? j['auto'] as bool : true,
      );
    } catch (_) {
      return Settings();
    }
  }
}

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
