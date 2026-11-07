import '../core/dates.dart';
import '../data/models.dart';

/// Какое расписание звонков действует в день [date].
String bellKeyFor(DateTime date) => date.weekday == DateTime.saturday ? kBellSat : kBellWeek;

String bellTitle(String key) => key == kBellSat ? 'Суббота' : 'Будни';

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

/// Как называть перерыв внутри пары: «обед» (от 20 минут) или «перерыв».
String innerBreakWord(BellSlot s) => s.lunchInside ? 'обед' : 'перерыв';

/// «45 + 45 мин» или «90 мин» — из чего состоит пара.
String halvesText(BellSlot s) => s.hasBreak ? '${s.firstHalf} + ${s.secondHalf} мин' : minText(s.minutes);

/// «08:30 – 10:00».
String slotRange(BellSlot s) => '${fmtMin(s.start)} – ${fmtMin(s.end)}';

/// «09:05–09:15» — короткая запись промежутка времени (минуты от полуночи).
String shortRange(int from, int to) => '${fmtMin(from)}–${fmtMin(to)}';


/// Готовое расписание звонков колледжа. [key] — для какого вида дней оно подходит (будни или суббота).
class BellPreset {
  const BellPreset({required this.id, required this.key, required this.title, required this.subtitle, required this.profile});
  final String id;
  final String key;
  final String title;
  final String subtitle;
  final BellProfile profile;
}

int _m(int h, int m) => h * 60 + m;

/// Пара из двух уроков и перерыва между ними: (h1:m1–h2:m2), перерыв, (h3:m3–h4:m4).
BellSlot _pair(int h1, int m1, int h2, int m2, int h3, int m3, int h4, int m4) =>
    BellSlot(start: _m(h1, m1), end: _m(h4, m4), breakStart: _m(h2, m2), breakEnd: _m(h3, m3));

/// Расписания звонков МГТЭК: два варианта для пн–пт и один для субботы.
/// Окончания 2 пары в субботу (10:50 и 11:40) восстановлены по фото — стоит сверить с оригиналом.
final List<BellPreset> kBellPresets = [
  BellPreset(
    id: 'week1',
    key: kBellWeek,
    title: 'Расписание 1',
    subtitle: 'Пн–Пт · 7 пар · обед 11:50–12:20 перед 3 парой',
    profile: BellProfile(
      lunchAfter: 2,
      slots: {
        1: _pair(8, 20, 9, 5, 9, 15, 10, 0),
        2: _pair(10, 10, 10, 55, 11, 5, 11, 50),
        3: _pair(12, 20, 13, 5, 13, 15, 14, 0),
        4: _pair(14, 10, 14, 55, 15, 0, 15, 45),
        5: _pair(15, 55, 16, 40, 16, 45, 17, 30),
        6: _pair(17, 40, 18, 25, 18, 30, 19, 15),
        7: _pair(19, 25, 20, 10, 20, 15, 21, 0),
      },
    ),
  ),
  BellPreset(
    id: 'week2',
    key: kBellWeek,
    title: 'Расписание 2',
    subtitle: 'Пн–Пт · 7 пар · обед 12:45–13:15 посреди 3 пары',
    profile: BellProfile(
      slots: {
        1: _pair(8, 20, 9, 5, 9, 15, 10, 0),
        2: _pair(10, 10, 10, 55, 11, 5, 11, 50),
        3: _pair(12, 0, 12, 45, 13, 15, 14, 0),
        4: _pair(14, 10, 14, 55, 15, 0, 15, 45),
        5: _pair(15, 55, 16, 40, 16, 45, 17, 30),
        6: _pair(17, 40, 18, 25, 18, 30, 19, 15),
        7: _pair(19, 25, 20, 10, 20, 15, 21, 0),
      },
    ),
  ),
  BellPreset(
    id: 'sat',
    key: kBellSat,
    title: 'Расписание 3',
    subtitle: 'Суббота · 6 пар · для всех групп',
    profile: BellProfile(
      slots: {
        1: _pair(8, 20, 9, 5, 9, 10, 9, 55),
        2: _pair(10, 5, 10, 50, 10, 55, 11, 40),
        3: _pair(11, 50, 12, 35, 12, 40, 13, 25),
        4: _pair(13, 35, 14, 20, 14, 25, 15, 10),
        5: _pair(15, 20, 16, 5, 16, 10, 16, 55),
        6: _pair(17, 5, 17, 50, 17, 55, 18, 40),
      },
    ),
  ),
];

/// Что происходит в расписании дня в данную минуту.
enum DayPhase {
  /// Звонков для пар дня нет или время не определено.
  none,

  /// Занятия ещё не начались.
  before,

  /// Идёт пара.
  lesson,

  /// Идёт перерыв внутри пары.
  innerBreak,

  /// Перерыв (обед или окно) между парами.
  gap,

  /// Занятия закончились.
  after,
}

/// Состояние дня: фаза, нужная пара, сколько минут осталось и какая доля уже прошла (0…1).
class DayClock {
  const DayClock(this.phase, {this.pair, this.next, this.left = 0, this.progress = 0});
  final DayPhase phase;

  /// Текущая пара (для перерыва между парами — пара, после которой он идёт).
  final int? pair;

  /// Следующая пара (для «до начала» и перерыва между парами).
  final int? next;

  /// Минут до конца текущей фазы.
  final int left;
  final double progress;
}

/// Состояние дня в минуту [minute]; [lessons] — номера пар, которые есть в расписании этого дня.
DayClock dayClock(BellProfile profile, List<int> lessons, int minute) {
  final nums = [for (final n in lessons) if (profile[n] != null) n]..sort();
  if (nums.isEmpty) return const DayClock(DayPhase.none);
  final first = profile[nums.first]!;
  final last = profile[nums.last]!;
  if (minute < first.start) return DayClock(DayPhase.before, next: nums.first, left: first.start - minute);
  if (minute >= last.end) return DayClock(DayPhase.after, pair: nums.last);
  for (var i = 0; i < nums.length; i++) {
    final n = nums[i];
    final s = profile[n]!;
    if (minute >= s.start && minute < s.end) {
      if (s.hasBreak && minute >= s.breakStart! && minute < s.breakEnd!) {
        return DayClock(DayPhase.innerBreak, pair: n, left: s.breakEnd! - minute, progress: (minute - s.breakStart!) / s.breakMinutes);
      }
      return DayClock(DayPhase.lesson, pair: n, left: s.end - minute, progress: (minute - s.start) / s.minutes);
    }
    if (i + 1 < nums.length) {
      final next = profile[nums[i + 1]]!;
      if (minute >= s.end && minute < next.start) {
        return DayClock(DayPhase.gap, pair: n, next: nums[i + 1], left: next.start - minute, progress: (minute - s.end) / (next.start - s.end));
      }
    }
  }
  return const DayClock(DayPhase.none);
}

/// Подпись промежутка между двумя соседними парами дня: «Перерыв 10 мин», «Обед 40 мин»
/// или «Окно 1 ч 40 мин», если между парами в расписании дня нет одной или нескольких пар.
/// Возвращает null, если промежутка нет. [from] и [to] — номера пар в расписании дня.
String? gapBetween(BellProfile p, int from, int to) {
  final a = p[from];
  final b = p[to];
  final skipped = to - from > 1;
  final minutes = (a != null && b != null) ? b.start - a.end : null;
  if (minutes != null && minutes <= 0) return null;
  if (skipped) {
    final span = minutes == null ? '' : ' ${spanText(minutes)}';
    return 'Окно$span';
  }
  if (minutes == null) return null;
  return '${p.isLunchAfter(from) ? 'Обед' : 'Перерыв'} ${spanText(minutes)}';
}
