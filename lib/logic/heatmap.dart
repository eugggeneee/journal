import '../data/models.dart';

/// Пропуски одного месяца для тепловой карты: часы по дням и по предметам.
class MonthAbsences {
  MonthAbsences._(this.year, this.month, this.hoursByDay, this.bySubjectByDay);

  final int year;
  final int month;

  /// Часы за день месяца (1…31).
  final Map<int, int> hoursByDay;

  /// День месяца → предмет → часы.
  final Map<int, Map<String, int>> bySubjectByDay;

  int get totalHours => hoursByDay.values.fold(0, (a, b) => a + b);
  int get maxDayHours => hoursByDay.values.fold(0, (a, b) => a > b ? a : b);
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  factory MonthAbsences.of(Iterable<Absence> list, int year, int month) {
    final byDay = <int, int>{};
    final bySubject = <int, Map<String, int>>{};
    for (final a in list) {
      if (a.date.year != year || a.date.month != month) continue;
      final d = a.date.day;
      byDay[d] = (byDay[d] ?? 0) + a.hours;
      final m = bySubject.putIfAbsent(d, () => {});
      m[a.subject] = (m[a.subject] ?? 0) + a.hours;
    }
    return MonthAbsences._(year, month, byDay, bySubject);
  }

  /// Насыщенность клетки 0…1: самый «тяжёлый» день месяца даёт 1. Минимум 0,25, если пропуск был.
  double intensity(int day) {
    final h = hoursByDay[day] ?? 0;
    if (h <= 0) return 0;
    final max = maxDayHours;
    if (max <= 0) return 0;
    return (0.25 + 0.75 * (h / max)).clamp(0.25, 1.0).toDouble();
  }
}
