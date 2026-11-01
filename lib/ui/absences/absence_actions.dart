import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../kit/feedback.dart';

/// Быстрый переключатель пропуска пары: отметить (по умолчанию 1 или 2 часа) или снять.
void toggleLessonAbsence(BuildContext context, AppStore store, DateTime date, LessonSlot slot) {
  final m = ScaffoldMessenger.of(context);
  final before = store.snapshotDay(date);
  final existing = store.absenceFor(date, slot.number);
  if (existing != null) {
    store.deleteAbsence(existing.id);
    Haptics.light();
    showUndo(m, '${slot.number} пара — пропуск снят', () => store.restoreDay(date, before));
    return;
  }
  final hours = store.settings.absenceHours;
  store.saveAbsence(Absence(id: newId(), date: date, lesson: slot.number, subject: slot.subject, hours: hours));
  Haptics.medium();
  showUndo(m, '${slot.number} пара — пропуск ${hoursText(hours)}', () => store.restoreDay(date, before));
}

/// Отмечает все пары дня; если всё уже отмечено — снимает отметки.
void toggleWholeDay(BuildContext context, AppStore store, DateTime date, List<LessonSlot> slots) {
  if (slots.isEmpty) return;
  final m = ScaffoldMessenger.of(context);
  final before = store.snapshotDay(date);
  final lessons = {for (final s in slots) s.number};
  final allMarked = slots.every((s) => store.absenceFor(date, s.number) != null);
  if (allMarked) {
    store.clearAbsencesOn(date, lessons: lessons);
    Haptics.light();
    showUndo(m, 'Отметки дня сняты', () => store.restoreDay(date, before));
    return;
  }
  final hours = store.settings.absenceHours;
  final fresh = <Absence>[
    for (final s in slots)
      if (store.absenceFor(date, s.number) == null)
        Absence(id: newId(), date: date, lesson: s.number, subject: s.subject, hours: hours),
  ];
  store.saveAbsences(fresh);
  Haptics.medium();
  final total = slots.fold<int>(0, (sum, s) => sum + (store.absenceFor(date, s.number)?.hours ?? 0));
  showUndo(m, 'Пропущен весь день: ${pairsText(slots.length)} · ${hoursText(total)}', () => store.restoreDay(date, before));
}
