import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../../../core/palette.dart';

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

// Контейнеры используют светлые фиксированные тона Material 3 в обеих темах.
// Акцент для пиктограмм и графиков имеет отдельную контрастную роль.
const _anchors = [
  (0, 'red'),
  (16, 'deepOrange'),
  (30, 'orange'),
  (44, 'amber'),
  (76, 'lime'),
  (128, 'green'),
  (152, 'teal'),
  (180, 'cyan'),
  (214, 'blue'),
  (268, 'deepPurple'),
  (300, 'purple'),
  (340, 'pink'),
  (360, 'red'),
];
typedef _Accent = ({Tone tone, Color edge});
final _accentCache = <(Brightness, int), _Accent>{};

_Accent _materialAccent(BuildContext context, double hue) {
  final brightness = Theme.of(context).brightness;
  final degree = hue.round() % 360;
  return _accentCache.putIfAbsent((brightness, degree), () {
    final upper = _anchors.indexWhere((a) => a.$1 > degree);
    final (lo, first) = _anchors[upper - 1];
    final (hi, last) = _anchors[upper];
    final fraction = (degree - lo) / (hi - lo);
    final a = AppPalette.scheme(AppPalette.byId(first), brightness);
    final b = AppPalette.scheme(AppPalette.byId(last), brightness);
    Color mix(Color x, Color y) => Color.lerp(x, y, fraction)!;
    final pale = mix(a.primaryFixed, b.primaryFixed);
    final dim = mix(a.primaryFixedDim, b.primaryFixedDim);
    final fill = Color.lerp(pale, dim, brightness == Brightness.dark ? .70 : .12)!;
    return (tone: Tone(fill, mix(a.onPrimaryFixed, b.onPrimaryFixed)), edge: mix(a.primary, b.primary));
  });
}

Tone gradeTone(BuildContext context, num v) => _materialAccent(context, _gradeHue(v)).tone;
Color gradeAccent(BuildContext context, num v) => _materialAccent(context, _gradeHue(v)).edge;
Tone absenceTone(BuildContext context, {required bool excused}) => _materialAccent(context, excused ? 152 : 4).tone;
Color absenceAccent(BuildContext context, {required bool excused}) => _materialAccent(context, excused ? 152 : 4).edge;
Tone warnTone(BuildContext context) => _materialAccent(context, kHueAmber).tone;
Color warnAccent(BuildContext context) => _materialAccent(context, kHueAmber).edge;

/// Нейтральный тон (пока ничего не выбрано).
Tone neutralTone(BuildContext context) => Tone(context.cs.surfaceContainerHighest, context.cs.onSurfaceVariant);

/// Читаемый цвет текста поверх заливки [c].
Color onColorFor(Color c) =>
    ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : const Color(0xFF1B1B1F);

// Акценты разделов и настроек.
const double kHueBlue = 214;
const double kHueViolet = 268;
const double kHueRose = 340;
const double kHueAmber = 42;
const double kHueGreen = 146;
const double kHueTeal = 180;

/// Семейства оттенков для значков настроек.
const List<double> kSettingHues = [kHueBlue, kHueViolet, kHueRose, kHueAmber, kHueGreen, kHueTeal, 16, 300];

/// Пастельный фон и тёмный текст заданного оттенка (светлая и тёмная тема подбираются сами).
Tone hueTone(BuildContext context, double hue) => _materialAccent(context, hue).tone;

/// Насыщенный цвет заданного оттенка: для полос, точек и значков.
Color hueAccent(BuildContext context, double hue) => _materialAccent(context, hue).edge;

/// Постоянный оттенок значка настройки.
double settingHue(String title) {
  var h = 0;
  for (final u in title.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return kSettingHues[h % kSettingHues.length];
}
