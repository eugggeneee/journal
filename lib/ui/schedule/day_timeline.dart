import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';

/// Время масштабируется внутри каждого интервала. Если тексту нужно больше места,
/// его часовые риски и метка текущего времени растягиваются вместе с карточкой.
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.date, required this.slots, required this.store, required this.now});
  final DateTime date;
  final List<LessonSlot> slots;
  final AppStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final profile = store.bellProfileFor(date);
    final minute = sameDay(date, now) ? now.hour * 60 + now.minute : null;
    final numbered = [...slots]..sort((a, b) => a.number.compareTo(b.number));
    final timed = numbered.where((s) => profile[s.number] != null).toList()
      ..sort((a, b) => profile[a.number]!.start.compareTo(profile[b.number]!.start));
    final next = timed.where((s) => minute != null && profile[s.number]!.start > minute).firstOrNull;
    final rows = <Widget>[];
    const scale = 1.6;
    void interval(int start, int end, Widget child) {
      if (end <= start) return;
      rows.add(_Interval(start: start, end: end, minute: minute, child: child));
    }

    for (var i = 0; i < timed.length; i++) {
      final slot = timed[i];
      final b = profile[slot.number]!;
      final previous = i == 0 ? null : timed[i - 1];
      final start = previous == null ? b.start ~/ 60 * 60 : profile[previous.number]!.end;
      if (start < b.start) {
        final gap = previous == null ? null : gapBetween(profile, previous.number, slot.number);
        interval(
          start,
          b.start,
          Container(
            alignment: Alignment.centerLeft,
            constraints: BoxConstraints(minHeight: (b.start - start) * scale),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: gap == null
                ? null
                : Text(gap, style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant)),
          ),
        );
      }
      interval(
        b.start,
        b.end,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: LessonCard(
            slot: slot,
            date: date,
            store: store,
            minute: minute,
            next: slot == next,
            minHeight: math.max(0, b.minutes * scale - 4),
          ),
        ),
      );
    }
    if (numbered.any((s) => profile[s.number] == null)) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Время звонков не задано',
            style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ),
      );
    }
    for (final slot in numbered.where((s) => profile[s.number] == null)) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: LessonCard(slot: slot, date: date, store: store),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _Interval extends StatelessWidget {
  const _Interval({required this.start, required this.end, required this.minute, required this.child});
  final int start;
  final int end;
  final int? minute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const gutter = 54.0;
    final cs = context.cs;
    final m = minute;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                double y(int t) => (t - start) * box.maxHeight / (end - start);
                Widget tick(int t, {bool live = false}) => Positioned(
                  top: y(t) - 9,
                  left: 0,
                  right: 0,
                  height: 18,
                  child: Row(
                    children: [
                      Container(
                        width: gutter - 4,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: live ? cs.primary : cs.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            fmtMin(t),
                            style: context.tt.labelMedium?.copyWith(
                              fontWeight: live ? FontWeight.w800 : FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: live ? cs.onPrimary : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(height: live ? 2 : 1, color: live ? cs.primary : cs.outlineVariant),
                      ),
                    ],
                  ),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var t = ((start + 59) ~/ 60) * 60; t < end; t += 60)
                      if (m == null || (m - t).abs() > 12) tick(t),
                    if (m != null && m >= start && m < end) tick(m, live: true),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: gutter),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ],
    );
  }
}
