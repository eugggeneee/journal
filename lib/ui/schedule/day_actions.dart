import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/components/feedback.dart';
import '../kit/foundation/journal_theme.dart';

/// Пометка «Сокращённый день» на весь день: ставится одним нажатием, повторное нажатие снимает.
/// Вместе с пометкой день переходит на сокращённые звонки (пары по часу): они подставляются сами.
void toggleShortDay(BuildContext context, AppStore store, DateTime date) {
  final messenger = ScaffoldMessenger.of(context);
  final before = store.snapshotMarks(date);
  final existing = store.markFor(date, 0);
  Haptics.selection();
  if (existing != null && existing.label == kShortDayMark) {
    store.deleteMark(existing.id);
    showUndo(messenger, 'Сокращённый день снят', () => store.restoreMarks(date, before));
  } else {
    store.saveMark(DayMark(id: existing?.id ?? newId(), date: date, lesson: 0, label: kShortDayMark));
    showUndo(messenger, 'Сокращённый день: звонки изменены', () => store.restoreMarks(date, before));
  }
}

class DayToolbar extends StatelessWidget {
  const DayToolbar({super.key, required this.date, required this.slots, required this.store});
  final DateTime date;
  final List<LessonSlot> slots;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final profile = store.bellProfileFor(date);
    final bells = [for (final s in slots) profile[s.number]].whereType<BellSlot>().toList();
    String? range;
    if (bells.isNotEmpty) {
      final from = bells.map((b) => b.start).reduce((a, b) => a < b ? a : b);
      final to = bells.map((b) => b.end).reduce((a, b) => a > b ? a : b);
      range = shortRange(from, to);
    }
    final marked = [
      for (final s in slots)
        if (store.absenceFor(date, s.number) != null) s,
    ];
    final hours = marked.fold<int>(0, (a, s) => a + (store.absenceFor(date, s.number)?.hours ?? 0));
    final shortDay = store.markFor(date, 0)?.label == kShortDayMark;
    final sorted = [...bells]..sort((a, b) => a.start.compareTo(b.start));
    var breaks = bells.fold<int>(0, (sum, b) => sum + b.breakMinutes);
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].start - sorted[i - 1].end;
      if (gap > 0) breaks += gap;
    }
    final details = [
      pairsText(slots.length),
      ?range,
      if (breaks > 0) 'перерывы ${spanText(breaks)}',
      if (hours > 0) 'пропущено ${hoursText(hours)}',
      if (shortDay) kShortDayMark,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(longDate(date), style: tt.titleLarge?.copyWith(fontWeight: JournalType.heading)),
          const SizedBox(height: 4),
          Text(details.join(' · '), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
