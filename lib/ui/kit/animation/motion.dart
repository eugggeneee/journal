import 'package:material_ui/material_ui.dart';

/// Единые длительности и кривые движения: все анимации приложения собраны из этих значений,
/// поэтому смена вкладок, карточек, шторок и счётчиков ощущается как одно целое.
class Motion {
  Motion._();

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

  /// Лёгкая «пружинка» для маленьких элементов, которые появляются на месте.
  static const Curve spring = Curves.easeOutBack;
}
