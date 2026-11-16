import 'package:material_ui/material_ui.dart';

import '../kit/animation/motion.dart';

/// Полоса дня: каждая пара (и каждая половина пары с перерывом внутри) рисуется своим закруглённым
/// отрезком, а перерывы, обед и окна остаются промежутками между ними. Цветом заливается то, что уже прошло.
/// Отрезки расположены по времени, поэтому длинный обед виден широким промежутком, а короткий перерыв узким.
class DayBar extends StatelessWidget {
  const DayBar({
    super.key,
    required this.segments,
    required this.minute,
    required this.fill,
    required this.track,
    this.marker,
    this.height = 10,
  });

  /// Отрезки в минутах от полуночи: (начало, конец), по возрастанию и без пересечений.
  final List<(int, int)> segments;

  /// Текущая минута: меньше начала дня — ничего не залито, больше конца — залито всё.
  final int minute;
  final Color fill;
  final Color track;

  /// Цвет метки «сейчас»; без него метка не рисуется.
  final Color? marker;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return SizedBox(height: height);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: minute.toDouble()),
      duration: context.motion(Motion.long),
      curve: Motion.standard,
      builder: (context, value, _) => SizedBox(
        height: height + 6,
        width: double.infinity,
        child: CustomPaint(
          painter: _DayBarPainter(
            segments: segments,
            minute: value,
            fill: fill,
            track: track,
            marker: marker,
            height: height,
          ),
        ),
      ),
    );
  }
}

class _DayBarPainter extends CustomPainter {
  const _DayBarPainter({
    required this.segments,
    required this.minute,
    required this.fill,
    required this.track,
    required this.marker,
    required this.height,
  });
  final List<(int, int)> segments;
  final double minute;
  final Color fill;
  final Color track;
  final Color? marker;
  final double height;

  /// Минимальный видимый промежуток между отрезками.
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final start = segments.first.$1;
    final end = segments.last.$2;
    final span = (end - start).toDouble();
    if (span <= 0 || size.width <= 0) return;
    final top = (size.height - height) / 2;
    final radius = Radius.circular(height / 2);
    final trackPaint = Paint()..color = track;
    final fillPaint = Paint()..color = fill;
    double x(num m) => (m - start) / span * size.width;

    for (final s in segments) {
      var left = x(s.$1);
      var right = x(s.$2);
      // Соседние отрезки разделяет промежуток не уже _gap, даже если перерыв короткий.
      if (s.$1 > start) left += _gap / 2;
      if (s.$2 < end) right -= _gap / 2;
      if (right - left < height) right = left + height;
      final rrect = RRect.fromLTRBR(left, top, right, top + height, radius);
      canvas.drawRRect(rrect, trackPaint);
      final done = ((minute - s.$1) / (s.$2 - s.$1)).clamp(0.0, 1.0).toDouble();
      if (done > 0) {
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRect(Rect.fromLTRB(left, top, left + (right - left) * done, top + height), fillPaint);
        canvas.restore();
      }
    }

    final m = marker;
    if (m != null && minute >= start && minute <= end) {
      final cx = x(minute).clamp(height / 2, size.width - height / 2).toDouble();
      canvas.drawCircle(Offset(cx, size.height / 2), height * 0.8, Paint()..color = m);
    }
  }

  @override
  bool shouldRepaint(_DayBarPainter old) =>
      old.minute != minute || old.fill != fill || old.track != track || old.marker != marker || old.height != height || old.segments != segments;
}
