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

/// Цвет оценки (или среднего балла): 1–3 красный, 4–5 оранжевый, 6–7 жёлтый, 8–10 зелёный.
Tone gradeTone(BuildContext context, num v) {
  final dark = context.isDark;
  if (v < 4) return dark ? const Tone(Color(0xFF601410), Color(0xFFF9B4AE)) : const Tone(Color(0xFFF9DEDC), Color(0xFF8C1D18));
  if (v < 6) return dark ? const Tone(Color(0xFF5A2C00), Color(0xFFFFB77C)) : const Tone(Color(0xFFFFDCC2), Color(0xFF8A4400));
  if (v < 8) return dark ? const Tone(Color(0xFF4F4600), Color(0xFFE2CB66)) : const Tone(Color(0xFFFBEA9C), Color(0xFF635700));
  return dark ? const Tone(Color(0xFF00531F), Color(0xFF9ADCA3)) : const Tone(Color(0xFFB7F0C0), Color(0xFF0F5223));
}

/// Насыщенный цвет оценки (для столбиков и графиков).
Color gradeAccent(BuildContext context, num v) {
  final dark = context.isDark;
  if (v < 4) return dark ? const Color(0xFFF2766C) : const Color(0xFFD93025);
  if (v < 6) return dark ? const Color(0xFFFF9A4D) : const Color(0xFFE8710A);
  if (v < 8) return dark ? const Color(0xFFE0C02E) : const Color(0xFFC9A400);
  return dark ? const Color(0xFF5DC275) : const Color(0xFF1E8E3E);
}

/// Тоны для пропусков: без уважительной причины / по уважительной.
Tone absenceTone(BuildContext context, {required bool excused}) {
  final s = context.cs;
  return excused ? Tone(s.tertiaryContainer, s.onTertiaryContainer) : Tone(s.errorContainer, s.onErrorContainer);
}
