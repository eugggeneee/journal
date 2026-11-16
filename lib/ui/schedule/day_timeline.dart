import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';

/// Лента дня: слева время начала и конца пары, посередине вертикальная шкала с узлами,
/// справа карточки пар и таблетки перерывов одной ширины с ними. Шкала заполняется цветом по мере
/// того, как проходит день: пройденные пары помечены галочкой, идущая выделена кольцом.
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.date, required this.slots, required this.store});
  final DateTime date;
  final List<LessonSlot> slots;
  final AppStore store;

  static const double _timesW = 50;
  static const double _railW = 28;

  @override
  Widget build(BuildContext context) {
    final profile = store.bellProfileFor(date);
    final now = DateTime.now();
    final minute = now.hour * 60 + now.minute;
    final diff = dayDiff(date, today());
    final hasTimes = slots.any((s) => profile[s.number] != null);
    final timesW = hasTimes ? _timesW : 0.0;
    final isToday = diff == 0;

    // Ближайшая пара, которая ещё не началась: на ней подпись «Дальше · через …».
    int? nextIndex;
    if (isToday) {
      for (var i = 0; i < slots.length; i++) {
        final b = profile[slots[i].number];
        if (b != null && minute < b.start) {
          nextIndex = i;
          break;
        }
      }
    }

    final rows = <Widget>[];
    var k = 0;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final bell = profile[slot.number];
      final isLast = i == slots.length - 1;
      final phase = _phase(diff, minute, bell);
      final double fill;
      switch (phase) {
        case _Ph.past:
          fill = 1;
        case _Ph.now:
          fill = bell == null ? 0 : ((minute - bell.start) / bell.minutes).clamp(0.0, 1.0).toDouble();
        case _Ph.future:
          fill = 0;
      }
      rows.add(_TimelineRow(
        index: k++,
        timesW: timesW,
        start: bell?.start,
        end: bell?.end,
        rail: _Rail(node: true, first: i == 0, last: isLast, reached: phase != _Ph.future, current: phase == _Ph.now, fill: fill),
        dim: isToday && phase == _Ph.past,
        current: phase == _Ph.now,
        bottomGap: isLast ? 0 : 8,
        child: LessonCard(
          slot: slot,
          date: date,
          store: store,
          phase: phase == _Ph.now
              ? LessonPhase.now
              : (phase == _Ph.past ? LessonPhase.past : (i == nextIndex ? LessonPhase.next : LessonPhase.later)),
          minutes: bell == null ? null : (phase == _Ph.now ? bell.end - minute : (i == nextIndex ? bell.start - minute : null)),
          progress: fill,
        ),
      ));

      if (isLast) continue;
      final next = slots[i + 1];
      final label = gapBetween(profile, slot.number, next.number);
      if (label == null) continue;
      final a = bell;
      final b = profile[next.number];
      double gapFill = 0;
      var active = false;
      if (diff < 0) {
        gapFill = 1;
      } else if (isToday && a != null && b != null) {
        if (minute >= b.start) {
          gapFill = 1;
        } else if (minute >= a.end) {
          active = true;
          gapFill = ((minute - a.end) / (b.start - a.end)).clamp(0.0, 1.0).toDouble();
        }
      }
      rows.add(_TimelineRow(
        index: k++,
        timesW: timesW,
        rail: _Rail(node: false, first: false, last: false, reached: gapFill > 0, current: false, fill: gapFill),
        dim: isToday && gapFill >= 1,
        bottomGap: 8,
        child: _GapPill(
          label: label,
          range: (a != null && b != null) ? shortRange(a.end, b.start) : null,
          lunch: label.startsWith('Обед'),
          window: label.startsWith('Окно'),
          active: active,
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  /// Где пара относительно «сейчас»: прошедшие дни целиком позади, будущие впереди.
  static _Ph _phase(int diff, int minute, BellSlot? bell) {
    if (diff < 0) return _Ph.past;
    if (diff > 0 || bell == null) return _Ph.future;
    if (minute >= bell.end) return _Ph.past;
    if (minute >= bell.start) return _Ph.now;
    return _Ph.future;
  }
}

enum _Ph { past, now, future }

/// Что рисовать на шкале в одной строке ленты.
class _Rail {
  const _Rail({required this.node, required this.first, required this.last, required this.reached, required this.current, required this.fill});

  /// В строке есть узел (у пары — да, у таблетки перерыва — нет).
  final bool node;
  final bool first;
  final bool last;

  /// Узел уже пройден (или идёт).
  final bool reached;
  final bool current;

  /// Доля заполненной цветом шкалы ниже узла (0…1).
  final double fill;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.timesW,
    required this.rail,
    required this.child,
    this.start,
    this.end,
    this.dim = false,
    this.current = false,
    this.bottomGap = 8,
  });
  final int index;
  final double timesW;
  final _Rail rail;
  final Widget child;
  final int? start;
  final int? end;
  final bool dim;
  final bool current;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final railLeft = timesW;
    final contentLeft = timesW + DayTimeline._railW + 2;
    final fade = context.motion(Motion.medium);
    const figures = [FontFeature.tabularFigures()];
    return Appear(
      index: index,
      child: Stack(fit: StackFit.passthrough, children: [
        // Шкала и узел занимают всю строку без нижнего зазора, поэтому узел стоит ровно по центру карточки.
        Positioned(
          left: railLeft,
          top: 0,
          bottom: 0,
          width: DayTimeline._railW,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: rail.fill),
            duration: context.motion(Motion.long),
            curve: Motion.standard,
            builder: (context, v, _) => CustomPaint(
              painter: _RailPainter(
                rail: rail,
                fill: v,
                gap: bottomGap,
                primary: cs.primary,
                onPrimary: cs.onPrimary,
                track: cs.surfaceContainerHighest,
                halo: cs.primaryContainer,
                surface: cs.surface,
                outline: cs.outline,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: contentLeft, bottom: bottomGap),
          child: AnimatedOpacity(opacity: dim ? 0.62 : 1, duration: fade, child: child),
        ),
        if (start != null)
          Positioned(
            left: 0,
            top: 0,
            bottom: bottomGap,
            width: timesW - 4,
            // Время стоит по центру карточки и никогда не обрезается: при крупном шрифте оно уменьшается.
            child: AnimatedOpacity(
              opacity: dim ? 0.62 : 1,
              duration: fade,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      fmtMin(start!),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontSize: 15, height: 1.15, fontWeight: FontWeight.w800, fontFeatures: figures, color: current ? cs.primary : cs.onSurface),
                    ),
                    if (end != null)
                      Text(
                        fmtMin(end!),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500, fontFeatures: figures, color: cs.onSurfaceVariant),
                      ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.rail,
    required this.fill,
    required this.gap,
    required this.primary,
    required this.onPrimary,
    required this.track,
    required this.halo,
    required this.surface,
    required this.outline,
  });
  final _Rail rail;
  final double fill;

  /// Нижний зазор строки: узел стоит по центру карточки, то есть выше середины строки на половину зазора.
  final double gap;
  final Color primary;
  final Color onPrimary;
  final Color track;
  final Color halo;
  final Color surface;
  final Color outline;

  static const double _width = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final h = size.height;
    final nodeY = (h - gap) / 2;
    final y0 = (rail.node && rail.first) ? nodeY : 0.0;
    final y1 = (rail.node && rail.last) ? nodeY : h;
    const r = Radius.circular(_width / 2);
    final roundTop = rail.node && rail.first;
    final roundBottom = rail.node && rail.last;

    RRect bar(double a, double b, {required bool top, required bool bottom}) => RRect.fromLTRBAndCorners(
          x - _width / 2,
          a,
          x + _width / 2,
          b,
          topLeft: top ? r : Radius.zero,
          topRight: top ? r : Radius.zero,
          bottomLeft: bottom ? r : Radius.zero,
          bottomRight: bottom ? r : Radius.zero,
        );

    if (y1 > y0) {
      canvas.drawRRect(bar(y0, y1, top: roundTop, bottom: roundBottom), Paint()..color = track);
      final paint = Paint()..color = primary;
      if (!rail.node) {
        final yf = y0 + (y1 - y0) * fill;
        if (yf > y0) canvas.drawRect(Rect.fromLTRB(x - _width / 2, y0, x + _width / 2, yf), paint);
      } else if (rail.reached) {
        if (!rail.first) canvas.drawRect(Rect.fromLTRB(x - _width / 2, 0, x + _width / 2, nodeY), paint);
        final yf = nodeY + (y1 - nodeY) * fill;
        if (yf > nodeY) canvas.drawRect(Rect.fromLTRB(x - _width / 2, nodeY, x + _width / 2, yf), paint);
      }
    }

    if (!rail.node) return;
    final c = Offset(x, nodeY);
    if (rail.current) {
      canvas.drawCircle(c, 14, Paint()..color = halo);
      canvas.drawCircle(c, 9.5, Paint()..color = primary);
      canvas.drawCircle(c, 3.6, Paint()..color = onPrimary);
    } else if (rail.reached) {
      canvas.drawCircle(c, 12, Paint()..color = surface);
      canvas.drawCircle(c, 9, Paint()..color = primary);
      final tick = Path()
        ..moveTo(x - 3.6, nodeY + 0.2)
        ..lineTo(x - 1.1, nodeY + 2.9)
        ..lineTo(x + 3.8, nodeY - 2.7);
      canvas.drawPath(
        tick,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = onPrimary,
      );
    } else {
      canvas.drawCircle(c, 12, Paint()..color = surface);
      canvas.drawCircle(
        c,
        7.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = outline,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.fill != fill ||
      old.gap != gap ||
      old.rail.node != rail.node ||
      old.rail.first != rail.first ||
      old.rail.last != rail.last ||
      old.rail.reached != rail.reached ||
      old.rail.current != rail.current ||
      old.primary != primary ||
      old.track != track ||
      old.surface != surface ||
      old.outline != outline ||
      old.halo != halo ||
      old.onPrimary != onPrimary;
}

/// Перерыв, обед или окно между парами: таблетка той же ширины, что и карточки пар.
class _GapPill extends StatelessWidget {
  const _GapPill({required this.label, required this.range, required this.lunch, required this.window, required this.active});
  final String label;
  final String? range;
  final bool lunch;
  final bool window;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final Color bg;
    final Color fg;
    if (active) {
      bg = lunch ? cs.tertiary : cs.secondary;
      fg = lunch ? cs.onTertiary : cs.onSecondary;
    } else if (lunch) {
      bg = cs.tertiaryContainer;
      fg = cs.onTertiaryContainer;
    } else {
      bg = cs.surfaceContainerHigh;
      fg = cs.onSurfaceVariant;
    }
    final icon = lunch ? Icons.restaurant_rounded : (window ? Icons.hourglass_empty_rounded : Icons.coffee_rounded);
    return AnimatedContainer(
      duration: context.motion(Motion.medium),
      curve: Motion.standard,
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
        if (range != null)
          Text(
            range!,
            maxLines: 1,
            style: context.tt.labelMedium?.copyWith(color: fg.withValues(alpha: 0.85), fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
      ]),
    );
  }
}
