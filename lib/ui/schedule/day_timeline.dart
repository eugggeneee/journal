import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/foundation/journal_theme.dart';
import 'lesson_card.dart';
import 'calendar_grid.dart';

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
    final darker = darkerLessons(slots, store);
    final rows = <Widget>[];
    for (var i = 0; i < timed.length; i++) {
      final slot = timed[i];
      final bell = profile[slot.number]!;
      final previous = i > 0 ? timed[i - 1] : null;
      final from = previous == null ? bell.start ~/ 60 * 60 : profile[previous.number]!.end;
      if (from < bell.start) {
        final gap = previous == null ? null : gapBetween(profile, previous.number, slot.number);
        rows.add(
          CalendarBand(
            start: from,
            end: bell.start,
            minute: minute,
            child: gap == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(gap, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                    ),
                  ),
          ),
        );
      }
      rows.add(
        CalendarBand(
          start: bell.start,
          end: bell.end,
          minute: minute,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
            child: LessonCard(
              slot: slot,
              date: date,
              store: store,
              darker: darker.contains(slot.number),
              minute: minute,
              next: slot == next,
            ),
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
          child: LessonCard(slot: slot, date: date, store: store, darker: darker.contains(slot.number)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
