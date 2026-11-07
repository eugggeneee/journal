import 'package:material_ui/material_ui.dart';

import 'motion.dart';

/// Показывает одну из страниц и скользит между ними по горизонтали: при переходе вправо новая страница
/// въезжает справа, прежняя уходит влево (и наоборот). Все страницы остаются в дереве, поэтому позиция
/// прокрутки и введённые данные сохраняются, а скрытые страницы не тратят кадры на анимации.
class TabSwitcher extends StatefulWidget {
  const TabSwitcher({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher> with SingleTickerProviderStateMixin {
  /// Насколько страница смещается при въезде: доля ширины, остальное достраивает прозрачность.
  static const double _travel = 0.16;

  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.long, value: 1);
  late final Animation<double> _slide = _c.drive(CurveTween(curve: Motion.emphasized));
  late final Animation<double> _fadeIn = _c.drive(CurveTween(curve: const Interval(0.25, 1.0, curve: Curves.easeOut)));
  late final Animation<double> _fadeOut = _c.drive(CurveTween(curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));

  late int _from = widget.index;
  int _dir = 1;

  @override
  void didUpdateWidget(TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _from = old.index;
    _dir = widget.index > old.index ? 1 : -1;
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final running = _c.value < 1;
          return Stack(fit: StackFit.expand, children: [
            for (var i = 0; i < widget.children.length; i++) _page(i, running),
          ]);
        },
      );

  Widget _page(int i, bool running) {
    final isTo = i == widget.index;
    final isFrom = running && i == _from && !isTo;
    final visible = isTo || isFrom;
    final Offset shift;
    final double opacity;
    if (!running || (!isTo && !isFrom)) {
      shift = Offset.zero;
      opacity = 1;
    } else if (isTo) {
      shift = Offset(_dir * _travel * (1 - _slide.value), 0);
      opacity = _fadeIn.value;
    } else {
      shift = Offset(-_dir * _travel * _slide.value, 0);
      opacity = 1 - _fadeOut.value;
    }
    return Offstage(
      key: ValueKey('tab-$i'),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !isTo,
          child: FractionalTranslation(
            translation: shift,
            child: Opacity(opacity: opacity.clamp(0.0, 1.0).toDouble(), child: widget.children[i]),
          ),
        ),
      ),
    );
  }
}
