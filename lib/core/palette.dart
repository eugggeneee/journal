import 'package:material_ui/material_ui.dart';

part 'palette_choices.dart';

/// Цветовая тема приложения: название и «семечко», из которого Material 3 строит всю схему.
class ThemeChoice {
  const ThemeChoice(this.id, this.name, this.seed, {this.mono = false});
  final String id;
  final String name;
  final Color seed;

  /// Чёрно-белая схема Material (без оттенков).
  final bool mono;
}

/// Палитра тем: стандартная, чёрно-белая и основные цвета Material Design.
/// Порядок и id совпадают со значками в assets/icons (см. assets/icons/icons.json).
class AppPalette {
  AppPalette._();

  /// Особое значение: «как в системе» — на Android 12+ цвета берутся из обоев (Material You),
  /// на остальных устройствах это стандартная тема.
  static const String auto = 'auto';

  static const String standardId = 'default';

  static const List<ThemeChoice> choices = _themeChoices;

  static String launcherFor(String id, Color? wallpaper) {
    if (id != auto || wallpaper == null) return byId(id).id;
    final target = HSLColor.fromColor(wallpaper);
    if (target.saturation < .09) return 'mono';
    double distance(ThemeChoice choice) {
      final color = HSLColor.fromColor(choice.seed);
      final hue = (color.hue - target.hue).abs();
      return (hue > 180 ? 360 - hue : hue) + (color.saturation - target.saturation).abs() * 12;
    }
    return choices.where((c) => !c.mono).reduce((a, b) => distance(a) <= distance(b) ? a : b).id;
  }

  static bool has(String id) => choices.any((c) => c.id == id);

  /// Неизвестный id (например, из чужой резервной копии) заменяется стандартной темой.
  static ThemeChoice byId(String id) {
    for (final c in choices) {
      if (c.id == id) return c;
    }
    return choices.first;
  }

  static final Map<String, ColorScheme> _cache = {};

  static ColorScheme scheme(ThemeChoice c, Brightness b) => _cache.putIfAbsent(
        '${c.id}|${b.name}',
        () => ColorScheme.fromSeed(
          seedColor: c.seed,
          brightness: b,
          // Светлая заливка сохраняет оттенок выбранного образца даже у жёлтой и лаймовой тем.
          primaryContainer: b == Brightness.light ? Color.lerp(c.seed, Colors.white, .74) : null,
          onPrimaryContainer: b == Brightness.light && c.mono ? Colors.black : null,
          dynamicSchemeVariant: c.mono ? DynamicSchemeVariant.monochrome : DynamicSchemeVariant.tonalSpot,
        ),
      );
}
