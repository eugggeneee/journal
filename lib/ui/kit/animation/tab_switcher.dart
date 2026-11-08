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
  /// Насколько страница смещается при въезде и уходе: доля ширины, остальное достраивает прозрачность.
  static const double _travel = 0.1;

  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.page, value: 1)
    ..addStatusListener(_onStatus);
  late final Animation<double> _slide = _c.drive(CurveTween(curve: Motion.emphasized));
  late final Animation<double> _fadeIn = _c.drive(CurveTween(curve: const Interval(0.2, 0.95, curve: Curves.easeOut)));
  late final Animation<double> _fadeOut = _c.drive(CurveTween(curve: const Interval(0.0, 0.4, curve: Curves.easeIn))).drive(Tween<double>(begin: 1, end: 0));

  late int _from = widget.index;
  Animation<Offset> _enter = const AlwaysStoppedAnimation<Offset>(Offset.zero);
  Animation<Offset> _leave = const AlwaysStoppedAnimation<Offset>(Offset.zero);

  void _onStatus(AnimationStatus status) {
    // Переход закончился: страницы возвращаются в обычное состояние без обёрток движения.
    if (status == AnimationStatus.completed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _from = old.index;
    final dir = widget.index > old.index ? 1.0 : -1.0;
    _enter = _slide.drive(Tween<Offset>(begin: Offset(dir * _travel, 0), end: Offset.zero));
    _leave = _slide.drive(Tween<Offset>(begin: Offset.zero, end: Offset(-dir * _travel, 0)));
    if (Motion.off) {
      _c.value = 1;
    } else {
      _c.duration = Motion.page;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _c.status == AnimationStatus.forward;
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < widget.children.length; i++) _page(i, running),
    ]);
  }

  Widget _page(int i, bool running) {
    final isTo = i == widget.index;
    final isFrom = running && i == _from && !isTo;
    final visible = isTo || isFrom;
    final Animation<double> opacity;
    final Animation<Offset> position;
    if (running && isTo) {
      opacity = _fadeIn;
      position = _enter;
    } else if (isFrom) {
      opacity = _fadeOut;
      position = _leave;
    } else {
      opacity = kAlwaysCompleteAnimation;
      position = const AlwaysStoppedAnimation<Offset>(Offset.zero);
    }
    // Состав обёрток всегда один и тот же, иначе страница потеряла бы своё состояние.
    return Offstage(
      key: ValueKey('tab-$i'),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !isTo,
          child: FadeTransition(
            opacity: opacity,
            child: SlideTransition(
              position: position,
              child: RepaintBoundary(child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}
