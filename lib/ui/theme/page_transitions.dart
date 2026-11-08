import 'package:material_ui/material_ui.dart';

import '../kit/animation/motion.dart';

/// Переход между экранами со стопкой по глубине: новый экран въезжает справа и отбрасывает мягкую тень
/// на прежний, прежний уходит влево, чуть уменьшается и затемняется; при возврате всё идёт в обратную сторону.
/// При выключенных анимациях экран меняется почти мгновенно.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  static const Curve _curve = Curves.easeInOutCubicEmphasized;
  static final Tween<Offset> _enter = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  static final Tween<Offset> _leave = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.22, 0));
  static final Tween<double> _shrink = Tween<double>(begin: 1, end: 0.96);

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
    final scrim = Colors.black.withValues(alpha: 0.14);
    final shadow = BoxDecoration(
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(-8, 0))],
    );
    final under = secondaryAnimation.drive(CurveTween(curve: _curve));
    return SlideTransition(
      position: under.drive(_leave),
      child: ScaleTransition(
        scale: under.drive(_shrink),
        child: DecoratedBoxTransition(
          decoration: secondaryAnimation.drive(DecorationTween(begin: const BoxDecoration(), end: BoxDecoration(color: scrim))),
          position: DecorationPosition.foreground,
          child: SlideTransition(
            position: animation.drive(CurveTween(curve: _curve)).drive(_enter),
            child: DecoratedBoxTransition(
              decoration: animation.drive(DecorationTween(begin: shadow, end: const BoxDecoration())),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
