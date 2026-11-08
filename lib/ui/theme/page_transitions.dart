import 'package:material_ui/material_ui.dart';

import '../kit/animation/motion.dart';

/// Переход между экранами со стопкой по глубине: новый экран въезжает справа, прежний уходит влево,
/// чуть уменьшается и затемняется; при возврате всё идёт в обратную сторону.
///
/// Тень у края въезжающего экрана нарисована узкой полосой-градиентом, а не размытой тенью всего
/// экрана: так кадры идут ровно даже на слабых устройствах. При выключенных анимациях экран меняется
/// почти мгновенно.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  static const Curve _curve = Curves.easeInOutCubicEmphasized;
  static const double _edgeWidth = 24;
  static final Tween<Offset> _enter = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  static final Tween<Offset> _leave = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.24, 0));
  static final Tween<double> _shrink = Tween<double>(begin: 1, end: 0.97);
  static final Tween<double> _dim = Tween<double>(begin: 0, end: 0.16);
  static final Tween<double> _edge = Tween<double>(begin: 1, end: 0);

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
      return SlideTransition(position: snap.drive(_enter), child: child);
    }
    final over = animation.drive(CurveTween(curve: _curve));
    final under = secondaryAnimation.drive(CurveTween(curve: _curve));
    final edge = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
        ),
      ),
    );
    return SlideTransition(
      position: under.drive(_leave),
      child: ScaleTransition(
        scale: under.drive(_shrink),
        child: Stack(fit: StackFit.expand, children: [
          SlideTransition(
            position: over.drive(_enter),
            child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
              child,
              Positioned(
                left: -_edgeWidth,
                top: 0,
                bottom: 0,
                width: _edgeWidth,
                child: IgnorePointer(child: FadeTransition(opacity: animation.drive(_edge), child: edge)),
              ),
            ]),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(opacity: under.drive(_dim), child: const ColoredBox(color: Colors.black)),
            ),
          ),
        ]),
      ),
    );
  }
}
