import 'package:material_ui/material_ui.dart';

extension BuildContextX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Size get screen => MediaQuery.sizeOf(this);
}

/// Пара цветов «фон — текст» для оценок и статусов.
class Tone {
  const Tone(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

// ───────────────────────── цвета оценок и статусов ─────────────────────────
//
// Чистая пастель: у каждой оценки свой оттенок (плавный переход от красного к мятно-зелёному),
// фон всегда светлый и прозрачно-чистый, текст — глубокий тон того же оттенка.
// В тёмной теме фон чуть мягче, но остаётся пастельным — никакой «грязи» из тёмно-коричневого и болотного.

/// Узлы шкалы: оценка → оттенок (в градусах, цветовой круг HSL).
const List<double> _scaleGrade = [1, 3, 4.5, 6, 7.5, 9, 10];
const List<double> _scaleHue = [4, 14, 30, 44, 76, 128, 152];

double _gradeHue(num v) {
  final x = v.toDouble().clamp(1.0, 10.0).toDouble();
  for (var i = 0; i < _scaleGrade.length - 1; i++) {
    if (x <= _scaleGrade[i + 1]) {
      final t = (x - _scaleGrade[i]) / (_scaleGrade[i + 1] - _scaleGrade[i]);
      return _scaleHue[i] + (_scaleHue[i + 1] - _scaleHue[i]) * t;
    }
  }
  return _scaleHue.last;
}

Color _hsl(double hue, double saturation, double lightness) =>
    HSLColor.fromAHSL(1, hue % 360, saturation, lightness).toColor();

Tone _pastel(BuildContext context, double hue) => context.isDark
    ? Tone(_hsl(hue, 0.66, 0.76), _hsl(hue, 0.70, 0.16))
    : Tone(_hsl(hue, 0.90, 0.86), _hsl(hue, 0.75, 0.20));

Color _accent(BuildContext context, double hue) =>
    context.isDark ? _hsl(hue, 0.78, 0.64) : _hsl(hue, 0.72, 0.50);

/// Цвет оценки (или среднего балла): пастельный фон и тёмный текст того же оттенка.
Tone gradeTone(BuildContext context, num v) => _pastel(context, _gradeHue(v));

/// Насыщенный цвет оценки (для столбиков, графиков и выбранной кнопки).
Color gradeAccent(BuildContext context, num v) => _accent(context, _gradeHue(v));

// ───────────────────────── статусы: пропуски и лимиты ─────────────────────────
//
// Красный и зелёный строятся как настоящие тональные схемы Material 3 от базовых цветов палитры
// Material Design (Red 500, Green 500, Amber 500) в яркой («vibrant») вариации: контейнеры и акценты
// одного семейства, чистые и без серых и коричневых примесей, в светлой и тёмной теме.

const Color _seedRed = Color(0xFFF44336);
const Color _seedGreen = Color(0xFF4CAF50);
const Color _seedAmber = Color(0xFFFFC107);

final Map<String, ColorScheme> _statusSchemes = {};

ColorScheme _statusScheme(BuildContext context, Color seed) {
  final b = context.isDark ? Brightness.dark : Brightness.light;
  return _statusSchemes.putIfAbsent(
    '${seed.hashCode}|${b.name}',
    () => ColorScheme.fromSeed(seedColor: seed, brightness: b, dynamicSchemeVariant: DynamicSchemeVariant.vibrant),
  );
}

/// Тоны для пропусков: без уважительной причины (красный) / по уважительной (зелёный).
Tone absenceTone(BuildContext context, {required bool excused}) {
  final s = _statusScheme(context, excused ? _seedGreen : _seedRed);
  return Tone(s.primaryContainer, s.onPrimaryContainer);
}

/// Насыщенный цвет пропуска (плашки, столбики, шкалы).
Color absenceAccent(BuildContext context, {required bool excused}) =>
    _statusScheme(context, excused ? _seedGreen : _seedRed).primary;

/// Предупреждающий тон (янтарный): «лимит близко».
Tone warnTone(BuildContext context) {
  final s = _statusScheme(context, _seedAmber);
  return Tone(s.primaryContainer, s.onPrimaryContainer);
}

/// Насыщенный янтарный: Amber 700 в светлой теме, Amber 300 в тёмной.
Color warnAccent(BuildContext context) => context.isDark ? Colors.amber.shade300 : Colors.amber.shade700;

/// Нейтральный тон (пока ничего не выбрано).
Tone neutralTone(BuildContext context) => Tone(context.cs.surfaceContainerHighest, context.cs.onSurfaceVariant);

/// Читаемый цвет текста поверх заливки [c].
Color onColorFor(Color c) =>
    ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : const Color(0xFF1B1B1F);
