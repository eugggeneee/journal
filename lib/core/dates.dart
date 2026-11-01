/// Работа с датами и русскими названиями (без intl — меньше точек отказа).
library;

const _weekdays = [
  'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье',
];
const _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _monthsGen = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const _monthsNom = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

String two(int n) => n.toString().padLeft(2, '0');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());

/// Безопасное прибавление дней (без ошибок на переходе летнего/зимнего времени).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Разница в целых днях между календарными датами.
int dayDiff(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ua.difference(ub).inDays;
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime? parseYmd(String s) {
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

String longDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthsGen[d.month - 1]}';
String shortDate(DateTime d) => '${d.day} ${_monthsGen[d.month - 1]}';
String fullDate(DateTime d) => '${d.day} ${_monthsGen[d.month - 1]} ${d.year}';
String monthYear(DateTime d) => '${_monthsNom[d.month - 1]} ${d.year}';

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Склонение: plural(2, 'час', 'часа', 'часов') → 'часа'.
String plural(int n, String one, String few, String many) {
  final a = n.abs() % 100;
  final b = a % 10;
  if (a > 10 && a < 20) return many;
  if (b > 1 && b < 5) return few;
  if (b == 1) return one;
  return many;
}

String hoursText(int h) => '$h ${plural(h, 'час', 'часа', 'часов')}';
String pairsText(int n) => '$n ${plural(n, 'пара', 'пары', 'пар')}';

/// 8.5 → «8,50»
String fmtAvg(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

String gradesText(int n) => '$n ${plural(n, 'оценка', 'оценки', 'оценок')}';
String subjectsText(int n) => '$n ${plural(n, 'предмет', 'предмета', 'предметов')}';
String daysText(int n) => '$n ${plural(n, 'день', 'дня', 'дней')}';

/// «Сегодня» / «Завтра» / «Вчера» / день недели.
String relativeDay(DateTime d) {
  final diff = dayDiff(d, today());
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Завтра';
  if (diff == -1) return 'Вчера';
  return weekdayName(d);
}
