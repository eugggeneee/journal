import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'motion.dart';

/// Отключены ли анимации в системе (для виджетов, которые решают это один раз при создании).
bool _systemReduceMotion() => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

/// Запоминает, какие записи (оценки, пропуски) появились уже после первого показа списка —
/// именно они должны плавно «въезжать», а не все сразу при открытии страницы.
class FreshTracker {
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _window = Duration(milliseconds: 900);

  final Map<String, DateTime> _first = {};
  bool _primed = false;

  /// Вызывается при сборке страницы со всеми id, которые сейчас есть в данных.
  void sync(Iterable<String> ids) {
    final live = ids.toSet();
    _first.removeWhere((id, _) => !live.contains(id));
    final now = DateTime.now();
    for (final id in live) {
      _first.putIfAbsent(id, () => _primed ? now : _epoch);
    }
    _primed = true;
  }

  /// Запись только что добавлена (или восстановлена кнопкой «Отменить»).
  bool isFresh(String id) {
    final t = _first[id];
    return t != null && DateTime.now().difference(t) < _window;
  }
}

/// Плавное появление элемента списка: высота раскрывается, содержимое проявляется.
/// Соседние элементы раздвигаются постепенно, а не перескакивают.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.animate, required this.child});

  /// Играть анимацию при создании. Для уже существующих записей — false.
  final bool animate;
  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.long,
    value: widget.animate && !_systemReduceMotion() ? 0.0 : 1.0,
  );
  late final Animation<double> _size = _c.drive(CurveTween(curve: Motion.standard));
  late final Animation<double> _fade = _c.drive(CurveTween(curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));

  @override
  void initState() {
    super.initState();
    if (_c.value < 1) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
        sizeFactor: _size,
        axisAlignment: -1,
        child: FadeTransition(opacity: _fade, child: widget.child),
      );
}

/// Плавно меняет размер блока, когда внутри появляется или исчезает содержимое.
/// Внутренним элементам нужны разные [Key], чтобы смена была заметна.
class Smooth extends StatelessWidget {
  const Smooth({super.key, required this.child, this.duration = Motion.short});
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final d = context.motion(duration);
    return AnimatedSize(
      duration: d,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.passthrough,
          children: [...previous, if (current != null) current],
        ),
        child: child,
      ),
    );
  }
}

/// Смена содержимого на месте (заголовок, подпись, текст кнопки): старое растворяется, новое проявляется
/// и чуть всплывает. Размер блока не анимируется. Новому содержимому нужен другой [Key].
class Swap extends StatelessWidget {
  const Swap({super.key, required this.child, this.alignment = Alignment.centerLeft, this.duration = Motion.short});
  final Widget child;
  final AlignmentGeometry alignment;
  final Duration duration;

  static final Tween<Offset> _rise = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: context.motion(duration),
        switchInCurve: Motion.standard,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(position: anim.drive(_rise), child: child),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: [...previous, if (current != null) current],
        ),
        child: child,
      );
}

/// Маленький элемент, который «выскакивает» на месте и так же исчезает — размеры родителя не меняются.
/// [child] == null — элемента нет. [token] меняется вместе с содержимым, чтобы смена цифры тоже была анимированной.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.token});
  final Widget? child;
  final Object? token;

  @override
  Widget build(BuildContext context) {
    final c = child;
    return AnimatedSwitcher(
      duration: context.motion(const Duration(milliseconds: 340)),
      reverseDuration: context.motion(Motion.short),
      switchInCurve: Motion.spring,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        // Кривая «с отскоком» выходит за 0…1, прозрачность ограничиваем отдельно.
        child: FadeTransition(opacity: anim.drive(CurveTween(curve: const Interval(0.0, 0.6))), child: child),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [...previous, if (current != null) current],
      ),
      child: c == null
          ? const SizedBox.shrink(key: ValueKey('popin-none'))
          : KeyedSubtree(key: ValueKey('popin-${token ?? 'on'}'), child: c),
    );
  }
}

/// Число, которое плавно «досчитывается» до нового значения (средний балл, часы).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.format, this.style});
  final double value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value),
        duration: context.motion(Motion.long),
        curve: Motion.standard,
        builder: (context, v, _) => Text(format(v), style: style),
      );
}

/// Мягкое появление элемента при первом показе: проявляется и всплывает снизу.
/// Элементы списка появляются каскадом — чем ниже, тем чуть позже ([index], не больше 7 шагов).
/// Если в системе отключены анимации, элемент показывается сразу.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.index = 0, this.offset = 0.12});
  final Widget child;
  final int index;

  /// Насколько элемент «всплывает»: доля его высоты.
  final double offset;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.long);
  late final Animation<double> _fade = _c.drive(CurveTween(curve: Curves.easeOut));
  late final Animation<Offset> _slide =
      _c.drive(CurveTween(curve: Motion.standard)).drive(Tween<Offset>(begin: Offset(0, widget.offset), end: Offset.zero));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_systemReduceMotion()) {
      _c.value = 1;
      return;
    }
    final step = widget.index < 0 ? 0 : (widget.index > 7 ? 7 : widget.index);
    if (step == 0) {
      _c.forward();
    } else {
      _timer = Timer(Duration(milliseconds: 45 * step), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
}

/// Лёгкое «вдавливание» при нажатии: элемент чуть уменьшается и пружинит обратно.
/// Не мешает нажатиям и смахиванию — только следит за пальцем.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.scale = 0.985});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  Offset _start = Offset.zero;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || context.reduceMotion) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      // палец поехал — это прокрутка или смахивание, а не нажатие
      onPointerMove: (e) {
        if (_down && (e.position - _start).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? Motion.press : Motion.short,
        curve: _down ? Curves.easeOut : Motion.release,
        child: widget.child,
      ),
    );
  }
}
