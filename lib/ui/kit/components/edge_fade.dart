import 'package:material_ui/material_ui.dart';

/// Мягкое затухание краёв прокручиваемого списка вместо резкого обрыва.
///
/// Затухание появляется только там, где за краем есть ещё содержимое: сверху, когда список прокручен,
/// снизу, пока не доехали до конца. Высота затухания плавно растёт от нуля вместе с прокруткой.
/// [top] и [bottom] — высота затухания в логических пикселях (0 отключает край).
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.top = 14, this.bottom = 28});
  final Widget child;
  final double top;
  final double bottom;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  /// dx — доля верхнего затухания (0…1), dy — доля нижнего.
  final ValueNotifier<Offset> _edge = ValueNotifier<Offset>(Offset.zero);
  Offset _pending = Offset.zero;

  @override
  void dispose() {
    _edge.dispose();
    super.dispose();
  }

  void _update(ScrollMetrics m, int depth) {
    if (depth != 0 || m.axis != Axis.vertical) return;
    final before = widget.top <= 0 ? 0.0 : (m.pixels / widget.top).clamp(0.0, 1.0).toDouble();
    final after = widget.bottom <= 0 ? 0.0 : (m.extentAfter / widget.bottom).clamp(0.0, 1.0).toDouble();
    final next = Offset(before, after);
    if (next == _pending) return;
    _pending = next;
    // Уведомления о размерах приходят во время раскладки, поэтому применяем значение после кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _edge.value != _pending) _edge.value = _pending;
    });
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          _update(n.metrics, n.depth);
          return false;
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) {
            _update(n.metrics, n.depth);
            return false;
          },
          child: ValueListenableBuilder<Offset>(
            valueListenable: _edge,
            child: widget.child,
            builder: (context, e, child) => ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final h = rect.height <= 0 ? 1.0 : rect.height;
                final t = (widget.top * e.dx / h).clamp(0.0, 0.5).toDouble();
                final b = (widget.bottom * e.dy / h).clamp(0.0, 0.5).toDouble();
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                  stops: [0, t, 1 - b, 1],
                ).createShader(rect);
              },
              child: child,
            ),
          ),
        ),
      );
}
