import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../kit/feedback.dart';
import 'absence_sheet.dart';

/// Значок пропуска у пары: если пропуска нет — сразу выезжает маленькая шторка с выбором
/// «без уважительной / по уважительной»; если есть — отметка снимается (с кнопкой «Отменить»).
void toggleLessonAbsence(BuildContext context, AppStore store, DateTime date, LessonSlot slot) {
  final existing = store.absenceFor(date, slot.number);
  if (existing == null) {
    showLessonAbsence(context, date, slot);
    return;
  }
  final m = ScaffoldMessenger.of(context);
  final before = store.snapshotDay(date);
  store.deleteAbsence(existing.id);
  Haptics.light();
  showUndo(m, '${slot.number} пара — пропуск снят', () => store.restoreDay(date, before));
}

/// «Весь день»: если не всё отмечено — шторка с выбором причины; если всё — отметки снимаются.
void toggleWholeDay(BuildContext context, AppStore store, DateTime date, List<LessonSlot> slots) {
  if (slots.isEmpty) return;
  final allMarked = slots.every((s) => store.absenceFor(date, s.number) != null);
  if (!allMarked) {
    showWholeDayAbsence(context, date, slots);
    return;
  }
  final m = ScaffoldMessenger.of(context);
  final before = store.snapshotDay(date);
  store.clearAbsencesOn(date, lessons: {for (final s in slots) s.number});
  Haptics.light();
  showUndo(m, 'Отметки дня сняты', () => store.restoreDay(date, before));
}
