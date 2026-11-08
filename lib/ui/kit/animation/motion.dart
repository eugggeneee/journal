import 'package:material_ui/material_ui.dart';

/// Единые длительности и кривые движения: все анимации приложения собраны из этих значений,
/// поэтому смена вкладок, карточек, шторок и счётчиков ощущается как одно целое.
///
/// Скорость задаёт настройка «Анимации»: выразительные (как задумано), спокойные (короче и тише)
/// и выключенные. Системная настройка «Убрать анимации» действует всегда.
class Motion {
  Motion._();

  /// Режим анимаций: 0 — выразительные, 1 — спокойные, 2 — выключены. Выставляется из настроек.
  static int level = 0;

  /// Анимации отключены настройкой приложения или системой.
  static bool get off =>
      level >= 2 || WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  static double get _scale => level == 1 ? 0.7 : 1.0;

  /// Длительность в миллисекундах с учётом режима анимаций.
  static Duration ms(int value) => off ? Duration.zero : Duration(microseconds: (value * 1000 * _scale).round());

  /// Шаг каскада: на сколько позже появляется следующий элемент списка.
  static Duration get stagger => ms(45);

  /// Нажатие: быстрое «вдавливание».
  static Duration get press => ms(90);

  /// Мелкие отклики: смена цвета, значка, галочки.
  static Duration get short => ms(220);

  /// Основное движение: появление блоков, смена режима, раскрытие.
  static Duration get medium => ms(320);

  /// Крупные элементы: итоговые карточки, счётчики, шкалы.
  static Duration get long => ms(480);

  /// Переход между вкладками и крупные смены экрана.
  static Duration get page => ms(420);

  /// Обычное «замедляющееся» движение Material.
  static const Curve standard = Curves.easeOutCubic;

  /// Выразительное движение Material 3 для крупных переходов.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Появление крупных элементов (шторки, карточки): быстрый старт и очень мягкая остановка.
  static const Curve decelerate = Easing.emphasizedDecelerate;

  /// Уход элементов: плавный разгон, без остановки на выходе.
  static const Curve accelerate = Easing.emphasizedAccelerate;

  /// Лёгкая «пружинка» для маленьких элементов, которые появляются на месте.
  static const Curve spring = Curves.easeOutBack;

  /// Пружинка при отпускании нажатой карточки.
  static const Curve release = Curves.easeOutBack;
}

extension MotionContext on BuildContext {
  /// Анимации отключены: настройкой приложения или системной настройкой «Убрать анимации».
  bool get reduceMotion => Motion.level >= 2 || MediaQuery.disableAnimationsOf(this);

  /// Длительность с учётом отключённых анимаций: тогда смена происходит сразу.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
