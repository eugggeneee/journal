import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';

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
    for (var i = 0; i < timed.length; i++) {
      final slot = timed[i];
      final bell = profile[slot.number]!;
      if (i > 0) {
        final prev = timed[i - 1];
        final gap = gapBetween(profile, prev.number, slot.number);
        if (gap != null) {
          final during = minute != null && minute >= profile[prev.number]!.end && minute < bell.start;
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: during
                        ? Text(fmtMin(minute), style: context.tt.labelLarge?.copyWith(color: context.cs.primary))
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      gap,
                      style: context.tt.labelMedium?.copyWith(
                        color: during ? context.cs.primary : context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
      final live = minute != null && minute >= bell.start && minute < bell.end;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fmtMin(bell.start),
                          style: context.tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: live ? context.cs.primary : context.cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fmtMin(bell.end),
                          style: context.tt.labelMedium?.copyWith(
                            color: context.cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (live)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.cs.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  fmtMin(minute),
                                  semanticsLabel: 'Сейчас ${fmtMin(minute)}',
                                  style: context.tt.labelMedium?.copyWith(
                                    color: context.cs.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LessonCard(slot: slot, date: date, store: store, minute: minute, next: slot == next),
              ),
            ],
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
