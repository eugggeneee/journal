import 'package:material_ui/material_ui.dart';

import '../../core/palette.dart';

/// Тема Material 3 (официальный пакет material_ui).
/// По умолчанию цвета берутся из обоев системы (Material You, Android 12+), а если их нет —
/// из стандартной темы. Пользователь может выбрать любую тему из [AppPalette].
class AppTheme {
  AppTheme._();

  /// Длительность и кривая плавной смены темы (цвета всего интерфейса перетекают друг в друга).
  static const Duration switchDuration = Duration(milliseconds: 600);
  static const Curve switchCurve = Curves.easeInOutCubicEmphasized;

  /// Есть ли на устройстве динамические цвета (Material You). Обновляется при запуске.
  static final ValueNotifier<bool> dynamicAvailable = ValueNotifier<bool>(false);

  static ColorScheme? _dynLight;
  static ColorScheme? _dynDark;

  static void setDynamic(ColorScheme? light, ColorScheme? dark) {
    _dynLight = light;
    _dynDark = dark;
    final has = light != null && dark != null;
    if (dynamicAvailable.value != has) {
      WidgetsBinding.instance.addPostFrameCallback((_) => dynamicAvailable.value = has);
    }
  }

  static ColorScheme? dynamicFor(Brightness b) => b == Brightness.dark ? _dynDark : _dynLight;

  /// Схема для выбранной темы и яркости.
  static ColorScheme schemeFor(String id, Brightness b) {
    if (id == AppPalette.auto) {
      return dynamicFor(b) ?? AppPalette.scheme(AppPalette.choices.first, b);
    }
    return AppPalette.scheme(AppPalette.byId(id), b);
  }

  /// Название выбранной темы для подписей.
  static String nameOf(String id, {required bool hasDynamic}) {
    if (id == AppPalette.auto) return hasDynamic ? 'По обоям' : AppPalette.choices.first.name;
    return AppPalette.byId(id).name;
  }

  static final Map<Brightness, ColorScheme> _lastScheme = {};
  static final Map<Brightness, ThemeData> _lastTheme = {};

  /// ThemeData для темы; пока схема не изменилась, возвращается один и тот же объект
  /// (не пересобирается при каждом изменении оценок и пропусков).
  static ThemeData themeFor(String id, Brightness b) {
    final s = schemeFor(id, b);
    final prev = _lastScheme[b];
    final cached = _lastTheme[b];
    if (prev != null && cached != null && identical(prev, s)) return cached;
    final t = build(s);
    _lastScheme[b] = s;
    _lastTheme[b] = t;
    return t;
  }

  static ThemeData build(ColorScheme s) {
    final shape24 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
    return ThemeData(
      colorScheme: s,
      scaffoldBackgroundColor: s.surface,
      // Только Material: на Android — предиктивный «назад», на остальных платформах — Material 3 «fade forwards».
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: s.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape24,
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: s.surfaceContainer,
        indicatorColor: s.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? s.onSurface : s.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: s.surfaceContainer,
        indicatorColor: s.secondaryContainer,
        useIndicator: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.primaryContainer,
        foregroundColor: s.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: s.outlineVariant),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurface),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: s.primary, width: 2)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: s.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: s.outlineVariant.withValues(alpha: 0.6), space: 1, thickness: 1),
    );
  }
}
