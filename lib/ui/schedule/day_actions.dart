import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/components/feedback.dart';
import '../kit/foundation/ctx.dart';
import 'marks.dart';
import 'whole_day_split.dart';

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

/// Тонкая панель дня над лентой: сколько пар и во сколько, сколько часов пропущено, и действие «Весь день»
/// с меню (сокращённый день, пометка). Вместо большой карточки: ленте остаётся больше места.
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
    final marked = [for (final s in slots) if (store.absenceFor(date, s.number) != null) s];
    final hours = marked.fold<int>(0, (a, s) => a + (store.absenceFor(date, s.number)?.hours ?? 0));
    final allMarked = slots.isNotEmpty && marked.length == slots.length;
    final shortDay = store.markFor(date, 0)?.label == kShortDayMark;
    final sorted = [...bells]..sort((a, b) => a.start.compareTo(b.start));
    var breaks = bells.fold<int>(0, (sum, b) => sum + b.breakMinutes);
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].start - sorted[i - 1].end;
      if (gap > 0) breaks += gap;
    }
    final details = [
      pairsText(slots.length), ?range,
      if (breaks > 0) 'перерывы ${spanText(breaks)}',
      if (hours > 0) 'пропущено ${hoursText(hours)}',
      if (shortDay) kShortDayMark,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final detail in details) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
            child: Text(detail, style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240), child: WholeDaySplit(
          fg: cs.primary, allMarked: allMarked, shortDay: shortDay, enabled: slots.isNotEmpty,
          onWholeDay: () => toggleWholeDay(context, store, date, slots),
          onShortDay: () => toggleShortDay(context, store, date),
          onMark: () { Haptics.selection(); showMarkSheet(context, date); },
        )),
      ]),
    );
  }
}
