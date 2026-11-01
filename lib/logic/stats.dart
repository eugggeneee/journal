import '../data/models.dart';

class SubjectStat {
  SubjectStat(this.subject, this.grades);
  final String subject;
  final List<Grade> grades; // по возрастанию даты

  int get count => grades.length;
  double get average => grades.fold<int>(0, (a, g) => a + g.value) / grades.length;
  Grade get last => grades.last;

  /// Как последняя оценка изменила средний балл (null, если оценка одна).
  double? get lastImpact {
    if (grades.length < 2) return null;
    final before = grades.sublist(0, grades.length - 1);
    final prev = before.fold<int>(0, (a, g) => a + g.value) / before.length;
    return average - prev;
  }
}

class GradeStats {
  GradeStats._(this.count, this.average, this.subjects, this.distribution);
  final int count;
  final double? average;
  final List<SubjectStat> subjects;

  /// Сколько оценок каждого достоинства: индекс 0 — «1», индекс 9 — «10».
  final List<int> distribution;

  static GradeStats of(List<Grade> grades) {
    final dist = List<int>.filled(10, 0);
    if (grades.isEmpty) return GradeStats._(0, null, const [], dist);
    final sorted = [...grades]..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final by = <String, List<Grade>>{};
    var sum = 0;
    for (final g in sorted) {
      by.putIfAbsent(g.subject, () => []).add(g);
      sum += g.value;
      dist[(g.value - 1).clamp(0, 9).toInt()]++;
    }
    final subjects = [for (final e in by.entries) SubjectStat(e.key, e.value)];
    return GradeStats._(sorted.length, sum / sorted.length, subjects, dist);
  }
}

class AbsenceStats {
  AbsenceStats._(this.totalHours, this.excusedHours, this.bySubjectHours);
  final int totalHours;
  final int excusedHours;
  int get unexcusedHours => totalHours - excusedHours;
  final Map<String, int> bySubjectHours;

  static AbsenceStats of(List<Absence> list) {
    var total = 0, excused = 0;
    final subject = <String, int>{};
    for (final a in list) {
      total += a.hours;
      if (a.excused) excused += a.hours;
      subject[a.subject] = (subject[a.subject] ?? 0) + a.hours;
    }
    return AbsenceStats._(total, excused, subject);
  }
}
