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

/// Набор оттенков из официальной палитры Material Design (material.io/design/color).
class _Md {
  const _Md({
    required this.lightBg,
    required this.lightFg,
    required this.darkBase,
    required this.darkFg,
    required this.accentLight,
    required this.accentDark,
  });

  /// Светлая тема: фон (оттенок 100) и текст (оттенок 800–900).
  final Color lightBg;
  final Color lightFg;

  /// Тёмная тема: насыщенный оттенок (800–900), который смешивается с поверхностью.
  final Color darkBase;
  final Color darkFg;

  /// Акцент для столбиков, индикаторов и выбранных кнопок.
  final Color accentLight;
  final Color accentDark;
}

const _red = _Md(
  lightBg: Color(0xFFFFCDD2), // Red 100
  lightFg: Color(0xFFB71C1C), // Red 900
  darkBase: Color(0xFFB71C1C), // Red 900
  darkFg: Color(0xFFFFCDD2), // Red 100
  accentLight: Color(0xFFE53935), // Red 600
  accentDark: Color(0xFFEF5350), // Red 400
);

const _orange = _Md(
  lightBg: Color(0xFFFFE0B2), // Orange 100
  lightFg: Color(0xFFBF360C), // Deep Orange 900
  darkBase: Color(0xFFE65100), // Orange 900
  darkFg: Color(0xFFFFE0B2), // Orange 100
  accentLight: Color(0xFFF57C00), // Orange 700
  accentDark: Color(0xFFFFA726), // Orange 400
);

const _yellow = _Md(
  lightBg: Color(0xFFFFECB3), // Amber 100
  lightFg: Color(0xFF4E342E), // Brown 800
  darkBase: Color(0xFFF9A825), // Yellow 800
  darkFg: Color(0xFFFFF9C4), // Yellow 100
  accentLight: Color(0xFFFBC02D), // Yellow 700
  accentDark: Color(0xFFFFCA28), // Amber 400
);

const _green = _Md(
  lightBg: Color(0xFFC8E6C9), // Green 100
  lightFg: Color(0xFF1B5E20), // Green 900
  darkBase: Color(0xFF1B5E20), // Green 900
  darkFg: Color(0xFFC8E6C9), // Green 100
  accentLight: Color(0xFF43A047), // Green 600
  accentDark: Color(0xFF66BB6A), // Green 400
);

const _blue = _Md(
  lightBg: Color(0xFFBBDEFB), // Blue 100
  lightFg: Color(0xFF0D47A1), // Blue 900
  darkBase: Color(0xFF0D47A1), // Blue 900
  darkFg: Color(0xFFBBDEFB), // Blue 100
  accentLight: Color(0xFF1E88E5), // Blue 600
  accentDark: Color(0xFF64B5F6), // Blue 300
);

/// Светлая тема — спокойный оттенок 100; тёмная — глубокий оттенок 900, смешанный с поверхностью,
/// чтобы большие карточки не «светились».
Tone _tone(BuildContext context, _Md m) {
  if (context.isDark) {
    return Tone(Color.lerp(context.cs.surface, m.darkBase, 0.46)!, m.darkFg);
  }
  return Tone(m.lightBg, m.lightFg);
}

Color _accent(BuildContext context, _Md m) => context.isDark ? m.accentDark : m.accentLight;

_Md _gradeSwatch(num v) {
  if (v < 4) return _red;
  if (v < 6) return _orange;
  if (v < 8) return _yellow;
  return _green;
}

/// Цвет оценки (или среднего балла): 1–3 красный, 4–5 оранжевый, 6–7 жёлтый, 8–10 зелёный.
Tone gradeTone(BuildContext context, num v) => _tone(context, _gradeSwatch(v));

/// Насыщенный цвет оценки (для столбиков, графиков и выбранной кнопки).
Color gradeAccent(BuildContext context, num v) => _accent(context, _gradeSwatch(v));

/// Тоны для пропусков: без уважительной причины (красный) / по уважительной (синий).
Tone absenceTone(BuildContext context, {required bool excused}) => _tone(context, excused ? _blue : _red);

Color absenceAccent(BuildContext context, {required bool excused}) => _accent(context, excused ? _blue : _red);

/// Нейтральный тон (пока ничего не выбрано).
Tone neutralTone(BuildContext context) => Tone(context.cs.surfaceContainerHighest, context.cs.onSurfaceVariant);

/// Читаемый цвет текста поверх заливки [c].
Color onColorFor(Color c) =>
    ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : const Color(0xFF1B1B1F);
