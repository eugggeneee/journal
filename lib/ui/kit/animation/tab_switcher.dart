import 'package:material_ui/material_ui.dart';

import 'motion.dart';

/// Показывает одну из страниц и скользит между ними по горизонтали: при переходе вправо новая страница
/// въезжает справа, прежняя уходит влево (и наоборот). Все страницы остаются в дереве, поэтому позиция
/// прокрутки и введённые данные сохраняются, а скрытые страницы не тратят кадры на анимации.
///
/// Во время перехода кадр не пересобирает страницы: движение и прозрачность отдают готовые
/// `SlideTransition` и `FadeTransition`, а каждая страница закэширована в своём `RepaintBoundary`.
class TabSwitcher extends StatefulWidget {
  const TabSwitcher({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
  late final _progress = _controller.drive(CurveTween(curve: Motion.decelerate));
  static const _atRest = AlwaysStoppedAnimation<Offset>(Offset.zero);
  List<Animation<double>> _opacity = [];
  List<Animation<Offset>> _position = [];

  @override
  void didUpdateWidget(TabSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index && widget.children.length == old.children.length) return;
    final active = _controller.isAnimating;
    final distance = Motion.level == 1 ? .025 : .075;
    final direction = widget.index >= old.index ? 1 : -1;
    final alpha = <Animation<double>>[];
    final offsets = <Animation<Offset>>[];
    for (var i = 0; i < widget.children.length; i++) {
      final incoming = i == widget.index;
      final wasVisible = active && i < _opacity.length;
      final from = wasVisible ? _opacity[i].value : (i == old.index ? 1.0 : 0.0);
      if (from == 0 && !incoming) {
        alpha.add(kAlwaysDismissedAnimation);
        offsets.add(_atRest);
        continue;
      }
      final entry = Offset(distance * direction, 0);
      final origin = wasVisible && from > 0 ? _position[i].value : (incoming ? entry : Offset.zero);
      alpha.add(_progress.drive(Tween<double>(begin: from, end: incoming ? 1 : 0)));
      offsets.add(_progress.drive(Tween<Offset>(begin: origin, end: incoming ? Offset.zero : -entry)));
    }
    _opacity = alpha;
    _position = offsets;
    if (context.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.duration = Motion.page;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = !context.reduceMotion && _controller.isAnimating;
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < widget.children.length; i++)
        Offstage(
          key: ValueKey('tab-$i'),
          offstage: i != widget.index && (!running || _opacity[i] == kAlwaysDismissedAnimation),
          child: TickerMode(
            enabled: i == widget.index,
            child: ExcludeFocus(
              excluding: i != widget.index,
              child: ExcludeSemantics(
                excluding: i != widget.index,
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: FadeTransition(
                    opacity: running ? _opacity[i] : kAlwaysCompleteAnimation,
                    child: SlideTransition(
                      position: running ? _position[i] : _atRest,
                      textDirection: Directionality.of(context),
                      child: RepaintBoundary(child: widget.children[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
