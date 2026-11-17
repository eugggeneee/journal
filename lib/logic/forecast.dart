/// Прогноз среднего балла: что нужно получить, чтобы дотянуть до цели.
class Forecast {
  const Forecast._(this.reached, this.count, this.value);

  /// Цель уже достигнута: средний балл не ниже цели.
  final bool reached;

  /// Сколько оценок нужно получить (null, если цель недостижима за разумное число оценок или оценок ещё нет).
  final int? count;

  /// Какой оценкой (одинаковой): от 1 до 10.
  final int? value;

  bool get possible => reached || count != null;

  static const Forecast done = Forecast._(true, 0, null);
  static const Forecast none = Forecast._(false, null, null);

  /// Самый быстрый путь к цели: минимальное число одинаковых оценок и их достоинство.
  /// [values] — уже полученные оценки (1…10), [goal] — целевой средний балл (1…10), [maxCount] — предел.
  /// Расчёт целочисленный, без ошибок округления: (сумма + k·v) / (n + k) ≥ цель.
  factory Forecast.to(List<int> values, int goal, {int maxCount = 6}) {
    if (values.isEmpty || goal < 1 || goal > 10) return none;
    final sum = values.fold<int>(0, (a, v) => a + v);
    final n = values.length;
    if (sum >= goal * n) return done;
    for (var k = 1; k <= maxCount; k++) {
      final need = goal * (n + k) - sum;
      final v = (need + k - 1) ~/ k;
      if (v <= 10) return Forecast._(false, k, v < 1 ? 1 : v);
    }
    return none;
  }
}

/// Подпись прогноза: «Цель достигнута», «Нужна одна оценка 9», «Нужно 2 оценки по 10».
String forecastText(Forecast f, int goal) {
  if (f.reached) return 'Цель $goal достигнута';
  final k = f.count;
  final v = f.value;
  if (k == null || v == null) return 'До $goal не дотянуть за ближайшие оценки';
  if (k == 1) return 'До $goal нужна одна оценка $v';
  final word = (k % 10 == 1 && k % 100 != 11)
      ? 'оценка'
      : ((k % 10 >= 2 && k % 10 <= 4 && (k % 100 < 12 || k % 100 > 14)) ? 'оценки' : 'оценок');
  return 'До $goal нужно $k $word по $v';
}
