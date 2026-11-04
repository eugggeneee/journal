import '../core/dates.dart';
import '../data/models.dart';

/// Лимит часов без уважительной причины в месяц и когда показывать «лимит близко».
const int kMonthLimit = 10;
const int kMonthWarnFrom = 7;

/// Лимит часов без уважительной причины в семестр и когда показывать предупреждение.
const int kSemesterLimit = 72;
const int kSemesterWarnFrom = 62;

/// Уровень предупреждения. [index] совпадает с уровнем, который запоминается при скрытии карточки.
enum LimitLevel { ok, near, reached }

LimitLevel limitLevel(int hours, {required int warnFrom, required int limit}) {
  if (hours >= limit) return LimitLevel.reached;
  if (hours >= warnFrom) return LimitLevel.near;
  return LimitLevel.ok;
}

/// Часы без уважительной причины за период (обе даты включительно).
int unexcusedHoursBetween(Iterable<Absence> list, DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  var sum = 0;
  for (final x in list) {
    if (x.excused) continue;
    final d = dateOnly(x.date);
    if (!d.isBefore(a) && !d.isAfter(b)) sum += x.hours;
  }
  return sum;
}

/// Часы без уважительной причины в календарном месяце даты [now]: с 1-го по последнее число.
/// С первого числа нового месяца счётчик начинается с нуля сам.
int monthUnexcusedHours(Iterable<Absence> list, DateTime now) =>
    unexcusedHoursBetween(list, DateTime(now.year, now.month, 1), monthEnd(now));

/// Семестр учебного года. Учебный год: с 1 сентября по 1 августа.
/// 1-й семестр заканчивается по кнопке в настройках — со дня нажатия сразу идёт 2-й, он длится до 1 августа.
class Semester {
  const Semester({required this.year, required this.number, required this.start, required this.end, this.upcoming = false});

  /// Год начала учебного года (для 2026/27 это 2026).
  final int year;

  /// 1 или 2.
  final int number;
  final DateTime start;

  /// Последний день семестра (включительно).
  final DateTime end;

  /// Каникулы (2 августа — 31 августа): показан ближайший 1-й семестр, он ещё не начался.
  final bool upcoming;

  String get key => '$year-$number';
  String get title => '$number-й семестр';
  String get years => '$year/${(year + 1) % 100 < 10 ? '0' : ''}${(year + 1) % 100}';
}

/// Учебный год (по году начала) для даты. Со 2 по 31 августа — следующий, ещё не начавшийся.
int academicYearOf(DateTime d) {
  final t = dateOnly(d);
  if (!t.isBefore(DateTime(t.year, 9, 1))) return t.year;
  if (t.isAfter(DateTime(t.year, 8, 1))) return t.year;
  return t.year - 1;
}

/// Дата начала 2-го семестра для учебного года или null, если 1-й семестр ещё не завершён.
DateTime? semesterSplit(int year, Map<String, String> splits) {
  final s = parseYmd(splits['$year'] ?? '');
  if (s == null) return null;
  final first = DateTime(year, 9, 1);
  final last = DateTime(year + 1, 8, 1);
  if (s.isBefore(first) || s.isAfter(last)) return null;
  return s;
}

Semester semesterFor(DateTime now, Map<String, String> splits) {
  final t = dateOnly(now);
  final y = academicYearOf(t);
  final yStart = DateTime(y, 9, 1);
  final yEnd = DateTime(y + 1, 8, 1);
  final split = semesterSplit(y, splits);
  if (t.isBefore(yStart)) {
    return Semester(year: y, number: 1, start: yStart, end: yEnd, upcoming: true);
  }
  if (split == null || t.isBefore(split)) {
    return Semester(year: y, number: 1, start: yStart, end: split == null ? yEnd : addDays(split, -1));
  }
  return Semester(year: y, number: 2, start: split, end: yEnd);
}

/// Завершить 1-й семестр можно, пока идёт именно он (не каникулы и не 2-й семестр).
bool canEndSemester(DateTime now, Map<String, String> splits) {
  final s = semesterFor(now, splits);
  return s.number == 1 && !s.upcoming;
}

int semesterUnexcusedHours(Iterable<Absence> list, Semester s) => unexcusedHoursBetween(list, s.start, s.end);

/// Ключи для запоминания скрытых предупреждений.
String monthDismissKey(DateTime now) => 'm:${monthKey(now)}';
String semesterDismissKey(Semester s) => 's:${s.key}';
