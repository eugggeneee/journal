import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';

/// Номера пар, перерывы и метка часов используют одну шкалу в минутах.
class DayBar extends StatelessWidget {
  const DayBar({
    super.key,
    required this.slots,
    required this.profile,
    required this.minute,
    required this.fg,
    required this.bg,
    required this.onOpen,
    this.compact = false,
  });
  final List<LessonSlot> slots;
  final BellProfile profile;
  final int minute;
  final Color fg;
  final Color bg;
  final bool compact;
  final ValueChanged<LessonSlot> onOpen;

  @override
  Widget build(BuildContext context) {
    final numbers = slots.map((s) => s.number).where((n) => profile[n] != null).toList()
      ..sort((a, b) => profile[a]!.start.compareTo(profile[b]!.start));
    if (numbers.isEmpty) return const SizedBox.shrink();
    final start = profile[numbers.first]!.start;
    final end = numbers.map((n) => profile[n]!.end).reduce(math.max);
    final active = minute >= start && minute < end;
    final height = compact ? 48.0 : 50.0;
    final top = !compact && active ? 28.0 : 0.0;
    return Semantics(
      label: 'Ход дня, с ${fmtMin(start)} до ${fmtMin(end)}${active ? ', сейчас ${fmtMin(minute)}' : ''}',
      container: true,
      child: LayoutBuilder(
        builder: (context, box) {
          double x(int m) => (m - start) / (end - start) * box.maxWidth;
          final badgeWidth = math.min(54.0, box.maxWidth);
          final markerX = x(minute).clamp(0.0, box.maxWidth).toDouble();
          final children = <Widget>[];
          for (var i = 0; i < numbers.length; i++) {
            final n = numbers[i];
            final b = profile[n]!;
            final slot = slots.firstWhere((s) => s.number == n);
            final left = x(b.start);
            final width = math.max(1.0, x(b.end) - left - 1);
            final done = ((minute - b.start) / b.minutes).clamp(0.0, 1.0).toDouble();
            children.add(
              Positioned(
                left: left,
                width: width,
                top: top,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(
                      compact
                          ? 4
                          : i == 0
                          ? 16
                          : 7,
                    ),
                    right: Radius.circular(
                      compact
                          ? 4
                          : i == numbers.length - 1
                          ? 16
                          : 7,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: fg.withValues(alpha: .12)),
                      if (done > 0)
                        Positioned(
                          left: 0,
                          bottom: 0,
                          width: width * done,
                          height: compact ? 3 : 4,
                          child: ColoredBox(color: fg),
                        ),
                      if (b.hasBreak && !compact && done < 1)
                        Positioned(
                          left: (b.breakStart! - b.start) / b.minutes * width,
                          width: math.max(2.0, b.breakMinutes / b.minutes * width),
                          height: 4,
                          bottom: 0,
                          child: ColoredBox(color: fg.withValues(alpha: .35)),
                        ),
                      if (width >= 16)
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$n',
                                  style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 18, height: 1),
                                ),
                                if (!compact && width >= 32) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    fmtMin(b.start),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      fontWeight: FontWeight.w600,
                                      color: fg,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Semantics(
                          button: true,
                          label: '${slot.number} пара, ${slot.subjects.join(' / ')}, ${fmtMin(b.start)}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(onTap: () => onOpen(slot)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (!compact && i + 1 < numbers.length) {
              final next = profile[numbers[i + 1]]!;
              final gap = x(next.start) - x(b.end);
              if (gap >= 4)
                children.add(
                  Positioned(
                    left: x(b.end),
                    width: gap,
                    top: top,
                    height: height,
                    child: Center(
                      child: Icon(
                        profile.isLunchAfter(n) ? Icons.circle_outlined : Icons.circle,
                        size: math.min(gap, profile.isLunchAfter(n) ? 9.0 : 4.0),
                        color: fg,
                      ),
                    ),
                  ),
                );
            }
          }
          if (active && !compact) {
            children.add(
              Positioned(
                left: markerX.clamp(0.0, math.max(0.0, box.maxWidth - 2)),
                top: 18,
                height: 12,
                width: 2,
                child: ColoredBox(color: fg),
              ),
            );
            children.add(
              Positioned(
                left: (markerX - badgeWidth / 2).clamp(0.0, box.maxWidth - badgeWidth),
                top: 0,
                width: badgeWidth,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmtMin(minute),
                        style: TextStyle(color: bg, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return SizedBox(
            height: top + height,
            child: Stack(children: children),
          );
        },
      ),
    );
  }
}
