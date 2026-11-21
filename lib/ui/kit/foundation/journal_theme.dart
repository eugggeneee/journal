import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

abstract final class JournalLayout {
  static const double heroRadius = 32;
  static const double cardRadius = 28;
  static const double panelRadius = 24;
  static const double joinedRadius = 6;
  static const double touchTarget = 48;
  static const double gap = 4;
  static const double inset = 16;
  static const rowPadding = EdgeInsets.symmetric(horizontal: inset, vertical: 12);
}

abstract final class JournalType {
  static const heading = FontWeight.w800;
  static const emphasis = FontWeight.w700;
  static const countdown = TextStyle(fontSize: 148, height: .93, letterSpacing: -5,
    fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]);
}

extension BuildContextX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Size get screen => MediaQuery.sizeOf(this);
}

SystemUiOverlayStyle overlayForSurface(Color surface) {
  final icons = ThemeData.estimateBrightnessForColor(surface) == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
  return icons.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons.statusBarIconBrightness,
    systemNavigationBarDividerColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Пара цветов «фон — текст» для оценок и статусов.
class Tone {
  const Tone(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

/// Один акцент для пиктограмм. Семантические шкалы оценок и часов независимы.
Tone iconTone(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return Tone(
    Color.lerp(dark ? scheme.surfaceContainer : scheme.primaryContainer, scheme.primary, dark ? .23 : .10)!,
    scheme.primary.r == scheme.primary.g && scheme.primary.g == scheme.primary.b
          ? (dark ? const Color(0xFFDEDEDE) : const Color(0xFF424242))
          : Color.lerp(scheme.onSurface, scheme.primary, dark ? .78 : .62)!,
  );
}

// На диаграммах и в журналах один балл всегда относится к одному семейству Material.
MaterialColor _gradeFamily(num grade) => switch (grade.round().clamp(1, 10)) {
  <= 2 => Colors.red,
  <= 4 => Colors.deepOrange,
  5 => Colors.orange,
  6 => Colors.amber,
  7 => Colors.lightBlue,
  8 => Colors.cyan,
  9 => Colors.teal,
  _ => Colors.green,
};

MaterialColor _hueFamily(double hue) => switch (hue % 360) {
  < 10 || >= 350 => Colors.red,
  < 24 => Colors.deepOrange,
  < 37 => Colors.orange,
  < 70 => Colors.amber,
  < 155 => Colors.green,
  < 170 => Colors.teal,
  < 195 => Colors.cyan,
  < 240 => Colors.blue,
  < 285 => Colors.deepPurple,
  < 325 => Colors.purple,
  _ => Colors.pink,
};

Tone _pastel(BuildContext context, MaterialColor family) {
  final fill = context.isDark
      ? Color.lerp(context.cs.surfaceContainerHigh, family.shade800, .48)!
      : family.shade100;
  return Tone(fill, onColorFor(fill));
}

Color _ink(BuildContext context, MaterialColor family) => context.isDark ? family.shade200 : family.shade900;

Tone gradeTone(BuildContext context, num v) => _pastel(context, _gradeFamily(v));
Color gradeAccent(BuildContext context, num v) {
  final family = _gradeFamily(v);
  final ink = _ink(context, family);
  if (context.isDark || (v != 5 && v != 6)) return ink;
  return Color.lerp(ink, Colors.black, .16)!;
}
Color gradeChartFill(num v) => _gradeFamily(v).shade200;
Tone absenceTone(BuildContext context, {required bool excused}) => _pastel(context, excused ? Colors.teal : Colors.red);
Color absenceAccent(BuildContext context, {required bool excused}) => _ink(context, excused ? Colors.teal : Colors.red);
Tone warnTone(BuildContext context) => _pastel(context, Colors.amber);
Color warnAccent(BuildContext context) => _ink(context, Colors.deepOrange);

/// Те же ступени интенсивности используются в календаре и его легенде.
Color absenceDayFill(BuildContext context, double intensity) => switch (intensity) {
  <= 0 => context.cs.surfaceContainerHigh,
  < .4 => Colors.red.shade50,
  < .7 => Colors.red.shade100,
  _ => Colors.red.shade200,
};

/// Нейтральный тон (пока ничего не выбрано).
Tone neutralTone(BuildContext context) => Tone(context.cs.surfaceContainerHighest, context.cs.onSurfaceVariant);

/// Читаемый цвет текста поверх заливки [c].
Color onColorFor(Color c) => c.computeLuminance() > .179 ? Colors.black : Colors.white;

// Акценты разделов и настроек.
const double kHueBlue = 214;
const double kHueViolet = 268;
const double kHueRose = 340;
const double kHueAmber = 42;
const double kHueGreen = 146;
const double kHueTeal = 180;


/// Пастельный фон и тёмный текст заданного оттенка (светлая и тёмная тема подбираются сами).
Tone hueTone(BuildContext context, double hue) => _pastel(context, _hueFamily(hue));

/// Насыщенный цвет заданного оттенка: для полос, точек и значков.
Color hueAccent(BuildContext context, double hue) => _ink(context, _hueFamily(hue));
