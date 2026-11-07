import 'package:material_ui/material_ui.dart';

/// Единые длительности и кривые движения: все анимации приложения собраны из этих значений,
/// поэтому смена вкладок, карточек, шторок и счётчиков ощущается как одно целое.
class Motion {
  Motion._();

  /// Нажатие: быстрое «вдавливание».
  static const Duration press = Duration(milliseconds: 90);

  /// Мелкие отклики: смена цвета, значка, галочки.
  static const Duration short = Duration(milliseconds: 220);

  /// Основное движение: появление блоков, смена режима, раскрытие.
  static const Duration medium = Duration(milliseconds: 320);

  /// Крупные элементы: итоговые карточки, счётчики, шкалы.
  static const Duration long = Duration(milliseconds: 480);

  /// Обычное «замедляющееся» движение Material.
  static const Curve standard = Curves.easeOutCubic;

  /// Выразительное движение Material 3 для крупных переходов.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Появление крупных элементов (шторки): быстрый старт и мягкая остановка.
  static const Curve decelerate = Easing.emphasizedDecelerate;

  /// Уход элементов: плавный разгон, без остановки на выходе.
  static const Curve accelerate = Easing.emphasizedAccelerate;

  /// Лёгкая «пружинка» для маленьких элементов, которые появляются на месте.
  static const Curve spring = Curves.easeOutBack;

  /// Пружинка при отпускании нажатой карточки.
  static const Curve release = Curves.easeOutBack;
}

extension MotionContext on BuildContext {
  /// Системная настройка «Убрать анимации».
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Длительность с учётом отключённых в системе анимаций: тогда смена происходит сразу.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
