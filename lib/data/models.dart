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


/// Профили звонков: будни и суббота.
const String kBellWeek = 'week';
const String kBellSat = 'sat';
const List<String> kBellKeys = [kBellWeek, kBellSat];

/// Максимальное число пар в расписании звонков.
const int kMaxPairs = 7;

/// Время одной пары (минуты от полуночи). Внутри пары может быть перерыв.
class BellSlot {
  const BellSlot({required this.start, required this.end, this.breakStart, this.breakEnd});
  final int start;
  final int end;
  final int? breakStart;
  final int? breakEnd;

  bool get hasBreak => breakStart != null && breakEnd != null;
  int get minutes => end - start;
  int get breakMinutes => hasBreak ? breakEnd! - breakStart! : 0;

  /// Перерыв внутри пары — это обед (от 20 минут), как в расписании 2: «12:00–12:45, обед, 13:15–14:00».
  bool get lunchInside => hasBreak && breakMinutes >= 20;

  /// Первая половина пары (до перерыва); без перерыва — вся пара.
  int get firstHalf => hasBreak ? breakStart! - start : minutes;

  /// Вторая половина пары (после перерыва); без перерыва — 0.
  int get secondHalf => hasBreak ? end - breakEnd! : 0;

  /// Время корректно: конец позже начала, перерыв целиком внутри пары.
  bool get valid =>
      start >= 0 &&
      end <= 24 * 60 &&
      end > start &&
      (!hasBreak || (breakStart! > start && breakEnd! > breakStart! && breakEnd! < end));

  BellSlot withoutBreak() => BellSlot(start: start, end: end);

  List<int> toJson() => [start, end, breakStart ?? -1, breakEnd ?? -1];

  static BellSlot? tryFromJson(Object? raw) {
    try {
      final l = (raw as List).map((e) => _int(e, -1)).toList();
      if (l.length < 2 || l[0] < 0 || l[1] <= l[0]) return null;
      final hasBreak = l.length >= 4 && l[2] >= 0 && l[3] > l[2];
      final slot = BellSlot(start: l[0], end: l[1], breakStart: hasBreak ? l[2] : null, breakEnd: hasBreak ? l[3] : null);
      return slot.valid ? slot : slot.withoutBreak();
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BellSlot &&
      other.start == start &&
      other.end == end &&
      other.breakStart == breakStart &&
      other.breakEnd == breakEnd;
  @override
  int get hashCode => Object.hash(start, end, breakStart, breakEnd);
}

/// Расписание звонков одного вида дней: время пар 1…7 и пара, после которой обед.
class BellProfile {
  const BellProfile({this.slots = const {}, this.lunchAfter = 0});
  final Map<int, BellSlot> slots;

  /// Номер пары, после которой обед; 0 — обеда нет.
  final int lunchAfter;

  bool get isEmpty => slots.isEmpty;
  BellSlot? operator [](int n) => slots[n];

  BellProfile withSlot(int n, BellSlot? slot) {
    final m = {...slots};
    if (slot == null) {
      m.remove(n);
    } else {
      m[n] = slot;
    }
    return BellProfile(slots: m, lunchAfter: lunchAfter);
  }

  /// Те же пары и тот же обед (для подсветки применённого готового расписания).
  bool sameAs(BellProfile o) {
    if (o.lunchAfter != lunchAfter || o.slots.length != slots.length) return false;
    for (final e in slots.entries) {
      if (o.slots[e.key] != e.value) return false;
    }
    return true;
  }

  BellProfile withLunch(int n) => BellProfile(slots: slots, lunchAfter: n);

  /// Номер следующей заданной пары после [n] (null — её нет).
  int? nextPair(int n) {
    for (var m = n + 1; m <= kMaxPairs; m++) {
      if (slots[m] != null) return m;
    }
    return null;
  }

  /// Сколько минут перерыв между парой [n] и следующей заданной парой.
  int? gapAfter(int n) {
    final a = slots[n];
    final next = nextPair(n);
    if (a == null || next == null) return null;
    return slots[next]!.start - a.end;
  }

  bool isLunchAfter(int n) => lunchAfter > 0 && lunchAfter == n;

  /// Пара, идущая в указанную минуту суток (null — сейчас перерыв или занятий нет).
  int? pairAt(int minute) {
    for (final e in slots.entries) {
      if (minute >= e.value.start && minute < e.value.end) return e.key;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        's': {for (final e in slots.entries) '${e.key}': e.value.toJson()},
        'l': lunchAfter,
      };

  factory BellProfile.fromJson(Object? raw) {
    try {
      final j = Map<String, dynamic>.from(raw as Map);
      final slots = <int, BellSlot>{};
      for (final e in Map<String, dynamic>.from((j['s'] as Map?) ?? const {}).entries) {
        final n = int.tryParse(e.key);
        final slot = BellSlot.tryFromJson(e.value);
        if (n != null && n >= 1 && n <= kMaxPairs && slot != null) slots[n] = slot;
      }
      final lunch = _int(j['l'], 0);
      return BellProfile(slots: slots, lunchAfter: lunch >= 1 && lunch < kMaxPairs ? lunch : 0);
    } catch (_) {
      return const BellProfile();
    }
  }

  /// Первая найденная проблема во времени пар (null — всё в порядке).
  String? get problem {
    final nums = slots.keys.toList()..sort();
    for (var i = 0; i < nums.length; i++) {
      final slot = slots[nums[i]]!;
      if (!slot.valid) return '${nums[i]} пара: проверьте время и перерыв внутри пары';
      if (i > 0) {
        final prev = slots[nums[i - 1]]!;
        if (slot.start < prev.end) return '${nums[i]} пара начинается раньше конца ${nums[i - 1]}-й';
      }
    }
    return null;
  }
}

/// Пометка к дате: «ОКР», «Зачёт», «Практика» или своя. [lesson] == 0 — на весь день.
class DayMark {
  DayMark({required this.id, required this.date, required this.lesson, required this.label});
  final String id;
  final DateTime date;
  final int lesson;
  final String label;

  bool get wholeDay => lesson <= 0;

  DayMark copyWith({DateTime? date, int? lesson, String? label}) =>
      DayMark(id: id, date: date ?? this.date, lesson: lesson ?? this.lesson, label: label ?? this.label);

  Map<String, dynamic> toJson() => {'id': id, 'd': ymd(date), 'l': lesson, 't': label};

  static DayMark? tryFromJson(Object? raw) {
    try {
      final j = Map<String, dynamic>.from(raw as Map);
      final d = parseYmd(_str(j['d']));
      final label = _str(j['t']).trim();
      if (d == null || label.isEmpty) return null;
      final l = _int(j['l'], 0);
      return DayMark(
        id: _str(j['id']).isEmpty ? newId() : _str(j['id']),
        date: d,
        lesson: l < 0 ? 0 : l,
        label: label,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Пометка «Сокращённый день» — шаблон пометки на весь день.
const String kShortDayMark = 'Сокращённый день';

/// Готовые названия пометок.
const List<String> kMarkPresets = ['ОКР', 'Зачёт', 'Практика', kShortDayMark];

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
    Map<String, BellProfile>? bells,
    Map<String, String>? semesterSplits,
    Map<String, int>? dismissed,
  })  : extraSubjects = extraSubjects ?? [],
        bells = bells ?? {},
        semesterSplits = semesterSplits ?? {},
        dismissed = dismissed ?? {};

  String group; // пусто — группа ещё не выбрана
  final List<String> extraSubjects; // предметы, добавленные вручную

  bool onboarded; // приветственные экраны уже пройдены
  int themeMode; // 0 — как в системе, 1 — светлая, 2 — тёмная
  String themeColor; // цветовая тема: 'auto' — подстраивается под систему (Material You), либо id из палитры
  int absenceHours; // сколько часов отмечать при быстром нажатии: 1 или 2
  bool haptics; // тактильная отдача
  bool autoRefresh; // подгружать расписание при запуске и возвращении в приложение

  /// Расписание звонков: 'week' (пн–пт) и 'sat' (суббота).
  final Map<String, BellProfile> bells;

  /// Конец 1-го семестра по учебным годам: '2026' → '2027-01-24' (с этой даты идёт 2-й семестр).
  final Map<String, String> semesterSplits;

  /// Скрытые предупреждения о лимитах: ключ периода → самый высокий скрытый уровень (1 — «близко», 2 — «лимит»).
  final Map<String, int> dismissed;

  BellProfile bell(String key) => bells[key] ?? const BellProfile();

  Map<String, dynamic> toJson() => {
        'group': group,
        'extra': extraSubjects,
        'onb': onboarded,
        'theme': themeMode,
        'tc': themeColor,
        'ah': absenceHours,
        'hap': haptics,
        'auto': autoRefresh,
        'bells': {for (final e in bells.entries) e.key: e.value.toJson()},
        'sem': semesterSplits,
        'dis': dismissed,
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
        // если группа уже выбрана — приветствие не показываем
        onboarded: j['onb'] is bool ? j['onb'] as bool : group.isNotEmpty,
        themeMode: theme >= 0 && theme <= 2 ? theme : 0,
        themeColor: color.isEmpty ? 'auto' : color,
        absenceHours: hours == 1 ? 1 : 2,
        haptics: j['hap'] is bool ? j['hap'] as bool : true,
        autoRefresh: j['auto'] is bool ? j['auto'] as bool : true,
        bells: {
          for (final e in Map<String, dynamic>.from((j['bells'] as Map?) ?? const {}).entries)
            if (kBellKeys.contains(e.key)) e.key: BellProfile.fromJson(e.value),
        },
        semesterSplits: {
          for (final e in Map<String, dynamic>.from((j['sem'] as Map?) ?? const {}).entries)
            if (int.tryParse(e.key) != null && parseYmd(_str(e.value)) != null) e.key: _str(e.value),
        },
        dismissed: {
          for (final e in Map<String, dynamic>.from((j['dis'] as Map?) ?? const {}).entries) e.key: _int(e.value, 0),
        },
      );
    } catch (_) {
      return Settings();
    }
  }
}

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
