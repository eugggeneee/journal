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
  static Duration get press => ms(110);

  /// Мелкие отклики: смена цвета, значка, галочки.
  static Duration get short => ms(220);

  /// Основное движение: появление блоков, смена режима, раскрытие.
  static Duration get medium => ms(320);

  /// Крупные элементы: итоговые карточки, счётчики, шкалы.
  static Duration get long => ms(480);

  /// Переход между вкладками и крупные смены экрана.
  static Duration get page => ms(450);

  /// Обычное движение: мгновенный отклик и очень мягкая остановка (стандартная кривая Material 3).
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Выразительное движение Material 3 для крупных переходов: плавный разгон и плавная остановка.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Появление крупных элементов (шторки, карточки): быстрый старт и очень мягкая остановка.
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Уход элементов: плавный разгон, без остановки на выходе.
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Мягкая «пружинка» для маленьких элементов, которые появляются на месте: перелёт около 5 %,
  /// без резкого отскока. Значение может ненамного выходить за 1, прозрачность ограничивают отдельно.
  static const Curve spring = Cubic(0.3, 1.4, 0.5, 1.0);

  /// Отпускание нажатой карточки: то же мягкое возвращение с едва заметным перелётом.
  static const Curve release = Cubic(0.3, 1.25, 0.5, 1.0);

  /// Проявление нового содержимого: чуть позже старта движения, чтобы оно не мелькало до того,
  /// как займёт место.
  static const Curve fadeIn = Interval(0.12, 1.0, curve: Curves.easeOut);

  /// Исчезновение старого содержимого в `AnimatedSwitcher` (значение при уходе падает от 1 к 0):
  /// прозрачность уходит за первые 60 % времени, чтобы старое не мешало новому.
  static const Curve fadeOut = Interval(0.4, 1.0, curve: Curves.easeIn);
}

/// Обрезает значение анимации до 0…1. Нужна, когда кривая с пружинкой ([Motion.spring]) выходит за 1,
/// а потребитель этого не допускает: прозрачность или другая кривая.
class UnitClamp extends Animatable<double> {
  const UnitClamp();

  @override
  double transform(double t) => t.clamp(0.0, 1.0).toDouble();
}

extension MotionAnimation on Animation<double> {
  /// Та же анимация, ограниченная диапазоном 0…1.
  Animation<double> get clamped => drive(const UnitClamp());
}

extension MotionContext on BuildContext {
  /// Анимации отключены: настройкой приложения или системной настройкой «Убрать анимации».
  bool get reduceMotion => Motion.level >= 2 || MediaQuery.disableAnimationsOf(this);

  /// Длительность с учётом отключённых анимаций: тогда смена происходит сразу.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
