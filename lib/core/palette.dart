import 'package:material_ui/material_ui.dart';

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
/// Порядок и id совпадают со значками в assets/icons (см. scripts/make_icons.py).
class AppPalette {
  AppPalette._();

  /// Особое значение: «как в системе» — на Android 12+ цвета берутся из обоев (Material You),
  /// на остальных устройствах это стандартная тема.
  static const String auto = 'auto';

  static const String standardId = 'default';

  static const List<ThemeChoice> choices = [
    ThemeChoice('default', 'Стандартная', Color(0xFF3B5BDB)),
    ThemeChoice('mono', 'Чёрно-белая', Color(0xFF757575), mono: true),
    ThemeChoice('red', 'Красная', Color(0xFFF44336)),
    ThemeChoice('pink', 'Розовая', Color(0xFFE91E63)),
    ThemeChoice('purple', 'Пурпурная', Color(0xFF9C27B0)),
    ThemeChoice('deepPurple', 'Фиолетовая', Color(0xFF673AB7)),
    ThemeChoice('indigo', 'Индиго', Color(0xFF3F51B5)),
    ThemeChoice('blue', 'Синяя', Color(0xFF2196F3)),
    ThemeChoice('lightBlue', 'Голубая', Color(0xFF03A9F4)),
    ThemeChoice('cyan', 'Бирюзовая', Color(0xFF00BCD4)),
    ThemeChoice('teal', 'Изумрудная', Color(0xFF009688)),
    ThemeChoice('green', 'Зелёная', Color(0xFF4CAF50)),
    ThemeChoice('lightGreen', 'Салатовая', Color(0xFF8BC34A)),
    ThemeChoice('lime', 'Лаймовая', Color(0xFFCDDC39)),
    ThemeChoice('yellow', 'Жёлтая', Color(0xFFFFEB3B)),
    ThemeChoice('amber', 'Янтарная', Color(0xFFFFC107)),
    ThemeChoice('orange', 'Оранжевая', Color(0xFFFF9800)),
    ThemeChoice('deepOrange', 'Коралловая', Color(0xFFFF5722)),
    ThemeChoice('brown', 'Коричневая', Color(0xFF795548)),
    ThemeChoice('blueGrey', 'Серо-синяя', Color(0xFF607D8B)),
  ];

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
          dynamicSchemeVariant: c.mono ? DynamicSchemeVariant.monochrome : DynamicSchemeVariant.tonalSpot,
        ),
      );
}
