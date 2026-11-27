import 'package:material_ui/material_ui.dart';

import 'motion.dart';

/// Штрих следует от короткого плеча галочки к длинному и стирается при отмене.
/// Смысл выбранного состояния озвучивает родительский элемент управления.
class SelectionMark extends StatelessWidget {
  const SelectionMark({super.key, required this.selected, required this.color, this.size = 20});

  final bool selected;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final target = selected ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: context.motion(Motion.short),
      curve: Motion.standard,
      builder: (context, fraction, _) => CustomPaint(
        size: Size.square(size),
        painter: _CheckStroke(fraction, color),
      ),
    );
  }
}

class _CheckStroke extends CustomPainter {
  const _CheckStroke(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0 || size.isEmpty) return;
    final path = Path()
      ..moveTo(size.width * .17, size.height * .52)
      ..lineTo(size.width * .40, size.height * .75)
      ..lineTo(size.width * .83, size.height * .29);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, fraction * metric.length), Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.shortestSide * .115);
  }

  @override
  bool shouldRepaint(_CheckStroke old) => fraction != old.fraction || color != old.color;
}
