import 'package:flutter/foundation.dart' show listEquals;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../kit/foundation/journal_theme.dart';

const double calendarGutter = 48;

/// Чередование начинается заново в каждом дне. Смена кабинета или порядка
/// подгрупп не меняет тон двух одинаковых занятий подряд.
Set<int> darkerLessons(Iterable<LessonSlot> slots, AppStore store) {
  final ordered = slots.toList()..sort((a, b) => a.number.compareTo(b.number));
  List<String>? previous;
  var darker = false;
  final result = <int>{};
  for (final slot in ordered) {
    final subjects =
        slot.subjects
            .map(
              (s) =>
                  store.subjectName(s.trim()).toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ').trim(),
            )
            .toSet()
            .toList()
          ..sort();
    if (previous != null && !listEquals(previous, subjects)) darker = !darker;
    if (darker) result.add(slot.number);
    previous = subjects;
  }
  return result;
}

Color lessonSurface(BuildContext context, bool darker) {
  final cs = context.cs;
  if (!darker) return cs.surfaceContainerHigh;
  return context.isDark ? cs.surfaceContainer : cs.surfaceContainerHighest;
}

/// Часы, события и текущее время привязаны к одним координатам. В режиме дня
/// интервал растёт с содержимым, в режиме недели шкала общая у всех колонок.
class CalendarBand extends StatelessWidget {
  const CalendarBand({
    super.key,
    required this.start,
    required this.end,
    required this.child,
    this.columns = 1,
    this.minute,
    this.todayColumn = 0,
    this.pixelsPerMinute = 1.35,
  });
  final int start;
  final int end;
  final int columns;
  final int? minute;
  final int todayColumn;
  final double pixelsPerMinute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final live = minute;
    final showTime = live != null && todayColumn >= 0 && live >= start && live < end;
    final text = context.tt.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final columnWidth = (box.maxWidth - calendarGutter) / columns;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < columns; i++)
                    Positioned(
                      left: calendarGutter + i * columnWidth,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: ColoredBox(color: cs.outlineVariant.withValues(alpha: .48)),
                    ),
                  for (var h = ((start + 59) ~/ 60) * 60; h < end; h += 60) ...[
                    Positioned(
                      left: calendarGutter,
                      right: 0,
                      top: (h - start) * box.maxHeight / (end - start),
                      height: 1,
                      child: ColoredBox(color: cs.outlineVariant.withValues(alpha: .50)),
                    ),
                    if (!showTime || (live - h).abs() * box.maxHeight / (end - start) > 22)
                      Positioned(
                        left: 0,
                        width: calendarGutter - 6,
                        top: (h - start) * box.maxHeight / (end - start),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(fmtMin(h), style: text),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: calendarGutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (end - start) * pixelsPerMinute, minWidth: double.infinity),
            child: child,
          ),
        ),
        if (showTime)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, box) {
                  final width = (box.maxWidth - calendarGutter) / columns;
                  final y = (live - start) * box.maxHeight / (end - start);
                  final left = calendarGutter + todayColumn * width;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: math.max(0, y - 9),
                        width: calendarGutter - 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                fmtMin(live),
                                semanticsLabel: 'Сейчас ${fmtMin(live)}',
                                style: text?.copyWith(color: cs.onPrimary, fontWeight: JournalType.heading),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: left,
                        width: columns == 1 ? 8 : width,
                        top: y,
                        height: 1.5,
                        child: ColoredBox(color: cs.primary),
                      ),
                      Positioned(
                        left: left - 3,
                        top: y - 2.25,
                        width: 6,
                        height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class CalendarDate extends StatelessWidget {
  const CalendarDate({super.key, required this.date, required this.selected, required this.onTap, this.marked = false});
  final DateTime date;
  final bool selected;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final isToday = sameDay(date, today());
    final fg = isToday ? cs.primary : cs.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      label: isToday ? 'Сегодня, ${longDate(date)}' : longDate(date),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekdayShort(date),
                    style: context.tt.labelMedium?.copyWith(color: isToday ? cs.primary : cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? cs.primary : null,
                      border: isToday && !selected ? Border.all(color: cs.primary, width: 1.5) : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${date.day}',
                        style: context.tt.titleMedium?.copyWith(
                          fontWeight: isToday || selected ? JournalType.heading : FontWeight.w600,
                          color: selected ? cs.onPrimary : fg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 3,
                    width: 8,
                    decoration: BoxDecoration(
                      color: marked ? cs.tertiary : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarDateDivider extends StatelessWidget {
  const CalendarDateDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Divider(
      height: 1,
      color: context.cs.outlineVariant.withValues(alpha: .6),
    ),
  );
}
