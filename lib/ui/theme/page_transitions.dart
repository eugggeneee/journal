import 'package:material_ui/material_ui.dart';

import '../kit/animation/motion.dart';

/// Переход между экранами: новый экран плавно проявляется и сдвигается справа налево, прежний чуть
/// смещается влево; при возврате всё идёт в обратную сторону. Без теней и затемнения: поверхности
/// остаются плоскими. При выключенных анимациях экран меняется сразу.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Duration get reverseTransitionDuration => Motion.medium;
  static final Tween<Offset> _enter = Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero);
  static final Tween<Offset> _leave = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.06, 0));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.reduceMotion) return child;
    final over = animation.drive(CurveTween(curve: Motion.decelerate));
    final under = secondaryAnimation.drive(CurveTween(curve: Motion.decelerate));
    final fade = animation.drive(CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    return SlideTransition(
      position: under.drive(_leave),
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(position: over.drive(_enter), child: child),
      ),
    );
  }
}
