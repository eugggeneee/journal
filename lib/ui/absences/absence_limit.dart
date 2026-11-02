import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../kit/ctx.dart';
import '../kit/reveal.dart';

/// Порог пропусков без уважительной причины.
const int kAbsenceLimit = 10;

/// С какого количества часов показывается счётчик «до лимита».
const int kAbsenceWarnFrom = 7;

/// Над карточкой пропусков: с 7 часов — счётчик до лимита, с 10 — значок с восклицательным знаком.
/// Считаются только часы без уважительной причины; по уважительной не важно сколько.
class AbsenceLimitBanner extends StatelessWidget {
  const AbsenceLimitBanner({super.key, required this.unexcusedHours});
  final int unexcusedHours;

  @override
  Widget build(BuildContext context) {
    final h = unexcusedHours;
    final Widget child;
    if (h >= kAbsenceLimit) {
      child = _LimitReached(key: const ValueKey('limit-reached'), hours: h);
    } else if (h >= kAbsenceWarnFrom) {
      child = _LimitCounter(key: const ValueKey('limit-counter'), hours: h);
    } else {
      child = const SizedBox(key: ValueKey('limit-none'), width: double.infinity);
    }
    return Smooth(child: child);
  }
}

/// 7–9 часов: кольцо-счётчик «N из 10» и сколько осталось.
class _LimitCounter extends StatelessWidget {
  const _LimitCounter({super.key, required this.hours});
  final int hours;

  @override
  Widget build(BuildContext context) {
    final tone = warnTone(context);
    final accent = warnAccent(context);
    final left = kAbsenceLimit - hours;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: 'Пропусков без уважительной причины $hours из $kAbsenceLimit часов, осталось ${hoursText(left)}',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 20, 16),
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(28)),
          child: Row(children: [
            SizedBox(
              width: 72,
              height: 72,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: hours / kAbsenceLimit),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CustomPaint(
                  painter: _RingPainter(progress: v, color: accent, track: tone.fg.withValues(alpha: 0.14), stroke: 8),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$hours', style: context.tt.headlineSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1)),
                      Text('из $kAbsenceLimit', style: context.tt.labelSmall?.copyWith(color: tone.fg.withValues(alpha: 0.8), height: 1.2)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Лимит близко', style: context.tt.titleMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  'Осталось ${hoursText(left)} без уважительной причины',
                  style: context.tt.bodyMedium?.copyWith(color: tone.fg.withValues(alpha: 0.9), height: 1.3),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 10 часов и больше: яркая карточка с большим значком «!».
class _LimitReached extends StatelessWidget {
  const _LimitReached({super.key, required this.hours});
  final int hours;

  @override
  Widget build(BuildContext context) {
    final accent = absenceAccent(context, excused: false);
    final fg = onColorFor(accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: 'Достигнут лимит: ${hoursText(hours)} пропусков без уважительной причины',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 20, 16),
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(28)),
          child: Row(children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: fg.withValues(alpha: 0.28), blurRadius: 0, spreadRadius: 5)],
                ),
                child: Icon(Icons.priority_high_rounded, size: 40, color: accent),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Лимит пропусков', style: context.tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  hours == kAbsenceLimit
                      ? 'Набрано ${hoursText(hours)} без уважительной причины'
                      : 'Набрано ${hoursText(hours)} без уважительной причины — лимит $kAbsenceLimit ч превышен',
                  style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.92), height: 1.3),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track, required this.stroke});
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    paint.color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    paint.color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}
