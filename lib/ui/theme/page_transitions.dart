import 'package:material_ui/material_ui.dart';

import '../kit/animation/motion.dart';

/// Переход между экранами: новый экран плавно проявляется и сдвигается справа налево, прежний чуть
/// смещается влево; при возврате всё идёт в обратную сторону. Без теней и затемнения: поверхности
/// остаются плоскими. При выключенных анимациях экран меняется почти мгновенно.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  static const Curve _curve = Curves.easeInOutCubicEmphasized;
  static final Tween<Offset> _snap = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
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
    if (Motion.off) {
      // Маршрут по-прежнему «идёт» своё время, но экран занимает место в первые доли процента.
      final snap = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.05),
        reverseCurve: const Interval(0.95, 1),
      );
      return SlideTransition(position: snap.drive(_snap), child: child);
    }
    final over = animation.drive(CurveTween(curve: _curve));
    final under = secondaryAnimation.drive(CurveTween(curve: _curve));
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
