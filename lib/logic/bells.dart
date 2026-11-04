import '../core/dates.dart';
import '../data/models.dart';

/// Какое расписание звонков действует в день [date].
String bellKeyFor(DateTime date, {required bool shortDay}) {
  if (shortDay) return kBellShort;
  return date.weekday == DateTime.saturday ? kBellSat : kBellWeek;
}

String bellTitle(String key) => switch (key) {
      kBellSat => 'Суббота',
      kBellShort => 'Сокращённый день',
      _ => 'Будни',
    };

/// Параметры быстрого заполнения звонков.
class BellPlan {
  const BellPlan({
    this.firstStart = 8 * 60 + 30,
    this.pairMinutes = 90,
    this.breakMinutes = 10,
    this.count = kMaxPairs,
    this.lunchAfter = 0,
    this.lunchMinutes = 30,
    this.innerBreak = 0,
  });
  final int firstStart;
  final int pairMinutes;
  final int breakMinutes;
  final int count;
  final int lunchAfter;
  final int lunchMinutes;

  /// Перерыв внутри пары, минут (0 — без перерыва); ставится посередине пары.
  final int innerBreak;
}

/// Раскладывает пары подряд: пара, перерыв, пара… с обедом после выбранной пары.
BellProfile generateBells(BellPlan p) {
  var t = p.firstStart;
  final slots = <int, BellSlot>{};
  for (var n = 1; n <= p.count && n <= kMaxPairs; n++) {
    final end = t + p.pairMinutes;
    if (end > 24 * 60) break;
    int? bs;
    int? be;
    if (p.innerBreak > 0 && p.innerBreak < p.pairMinutes - 2) {
      bs = t + (p.pairMinutes - p.innerBreak) ~/ 2;
      be = bs + p.innerBreak;
    }
    slots[n] = BellSlot(start: t, end: end, breakStart: bs, breakEnd: be);
    t = end + (n == p.lunchAfter ? p.lunchMinutes : p.breakMinutes);
  }
  final lunch = (p.lunchAfter >= 1 && p.lunchAfter < slots.length) ? p.lunchAfter : 0;
  return BellProfile(slots: slots, lunchAfter: lunch);
}

/// Подпись перерыва после пары [n]: «Обед 40 мин» или «Перерыв 10 мин» (null — следующей пары нет).
String? gapLabel(BellProfile p, int n) {
  final gap = p.gapAfter(n);
  if (gap == null || gap <= 0) return null;
  return '${p.isLunchAfter(n) ? 'Обед' : 'Перерыв'} ${minText(gap)}';
}

/// «08:30 – 10:00».
String slotRange(BellSlot s) => '${fmtMin(s.start)} – ${fmtMin(s.end)}';
