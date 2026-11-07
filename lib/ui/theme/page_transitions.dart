import 'package:material_ui/material_ui.dart';

/// Переход между экранами: новый экран въезжает справа, прежний уходит влево с небольшим сдвигом
/// и затемнением; при возврате всё идёт в обратную сторону.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  static const Curve _curve = Curves.easeInOutCubicEmphasized;
  static final Tween<Offset> _enter = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  static final Tween<Offset> _leave = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.22, 0));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scrim = Colors.black.withValues(alpha: 0.12);
    return SlideTransition(
      position: secondaryAnimation.drive(CurveTween(curve: _curve)).drive(_leave),
      child: DecoratedBoxTransition(
        decoration: secondaryAnimation.drive(DecorationTween(
          begin: const BoxDecoration(),
          end: BoxDecoration(color: scrim),
        )),
        position: DecorationPosition.foreground,
        child: SlideTransition(
          position: animation.drive(CurveTween(curve: _curve)).drive(_enter),
          child: child,
        ),
      ),
    );
  }
}
