import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../app/scope.dart';

/// Глубина у краёв прокручиваемого списка: содержимое не растворяется, а уходит под шапку и нижнюю
/// панель, как под настоящую поверхность. Верхняя и нижняя панели отбрасывают на список мягкую тень,
/// которая появляется только там, где за краем есть ещё содержимое, и растёт вместе с прокруткой.
///
/// [top] выключают там, где шапка лежит внутри прокручиваемой области (закреплённый `SliverAppBar`):
/// он сам отбрасывает тень, когда под него заезжает список.
/// Эффект выключается настройкой «Глубина прокрутки» и в режиме «Анимации выключены».
class ScrollDepth extends StatefulWidget {
  const ScrollDepth({super.key, required this.child, this.top = true, this.bottom = true});
  final Widget child;
  final bool top;
  final bool bottom;

  @override
  State<ScrollDepth> createState() => _ScrollDepthState();
}

class _ScrollDepthState extends State<ScrollDepth> {
  /// dx — глубина сверху (0…1), dy — снизу.
  final ValueNotifier<Offset> _edge = ValueNotifier<Offset>(Offset.zero);
  Offset _pending = Offset.zero;

  /// На каком расстоянии прокрутки тень набирает полную силу.
  static const double _ramp = 36;

  @override
  void dispose() {
    _edge.dispose();
    super.dispose();
  }

  void _update(ScrollMetrics m, int depth) {
    if (depth != 0 || m.axis != Axis.vertical) return;
    final before = widget.top ? Curves.easeOut.transform((m.pixels / _ramp).clamp(0.0, 1.0).toDouble()) : 0.0;
    final after = widget.bottom ? Curves.easeOut.transform((m.extentAfter / _ramp).clamp(0.0, 1.0).toDouble()) : 0.0;
    final next = Offset(before, after);
    if (next == _pending) return;
    _pending = next;
    // Уведомления о размерах приходят во время раскладки, поэтому применяем значение после кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _edge.value != _pending) _edge.value = _pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = StoreScope.of(context).settings;
    if (!settings.depth || settings.motion >= 2) return widget.child;
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final strength = (dark ? 0.46 : 0.17) * (settings.motion == 1 ? 0.7 : 1.0);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _update(n.metrics, n.depth);
        return false;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          _update(n.metrics, n.depth);
          return false;
        },
        child: Stack(fit: StackFit.passthrough, children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _DepthPainter(edge: _edge, color: Theme.of(context).colorScheme.shadow, strength: strength)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DepthPainter extends CustomPainter {
  _DepthPainter({required this.edge, required this.color, required this.strength}) : super(repaint: edge);
  final ValueNotifier<Offset> edge;
  final Color color;
  final double strength;

  static const double _topHeight = 20;
  static const double _bottomHeight = 26;

  /// Спад тени: плавная кривая вместо линейной, чтобы у границы не было заметной полосы.
  static const List<double> _stops = [0, 0.16, 0.36, 0.6, 0.82, 1];
  static const List<double> _falloff = [1, 0.58, 0.28, 0.1, 0.03, 0];

  void _band(Canvas canvas, Rect rect, Alignment from, Alignment to, double amount) {
    if (amount <= 0.001) return;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        from.alongSize(rect.size) + rect.topLeft,
        to.alongSize(rect.size) + rect.topLeft,
        [for (final f in _falloff) color.withValues(alpha: strength * amount * f)],
        _stops,
      );
    canvas.drawRect(rect, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final e = edge.value;
    _band(canvas, Rect.fromLTWH(0, 0, size.width, _topHeight), Alignment.topCenter, Alignment.bottomCenter, e.dx);
    _band(canvas, Rect.fromLTWH(0, size.height - _bottomHeight, size.width, _bottomHeight), Alignment.bottomCenter, Alignment.topCenter, e.dy);
  }

  @override
  bool shouldRepaint(_DepthPainter old) => old.color != color || old.strength != strength || old.edge != edge;
}
