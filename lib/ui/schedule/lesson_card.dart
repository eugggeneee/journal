import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_sheet.dart';

/// Содержимое растёт вместе с подгруппами, пометками и системным шрифтом.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.slot,
    required this.date,
    required this.store,
    this.minute,
    this.next = false,
  });
  final LessonSlot slot;
  final DateTime date;
  final AppStore store;
  final int? minute;
  final bool next;

  static String roomText(String r) => r.isEmpty ? '' : (RegExp(r'^\d').hasMatch(r) ? 'ауд. $r' : r);

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final bell = store.bellFor(date, slot.number);
    final m = minute;
    final live = m != null && bell != null && m >= bell.start && m < bell.end;
    final inner = live && bell.hasBreak && m >= bell.breakStart! && m < bell.breakEnd!;
    final past = bell != null && m != null && m >= bell.end;
    final absence = store.absenceFor(date, slot.number);
    final mark = store.markFor(date, slot.number);
    final tasks = store.tasksForLesson(date, slot.number);
    final fg = live ? cs.onPrimaryContainer : cs.onSurface;
    final muted = live ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final chip = live ? Tone(cs.primary, cs.onPrimary) : Tone(cs.secondaryContainer, cs.onSecondaryContainer);
    final info = [if (bell != null) shortRange(bell.start, bell.end), '${slot.number} пара'].join(' · ');
    final accent = hueAccent(context, subjectHue(slot.subjects.firstOrNull ?? ''));
    final eventColor = Color.alphaBlend(accent.withValues(alpha: past ? .10 : .18), cs.surfaceContainerLow);
    final state = inner
        ? 'Сейчас ${innerBreakWord(bell)}'
        : live
        ? 'Идёт сейчас'
        : next && bell != null && m != null
        ? 'Через ${spanText(bell.start - m)}'
        : null;

    return SegmentCard(
      index: 0,
      count: 1,
      appear: false,
      borderRadius: BorderRadius.circular(live ? 20 : 14),
      color: live ? cs.primaryContainer : eventColor,
      onTap: () => showLessonSheet(context, date, slot),
      onLongPress: () => toggleLessonAbsence(context, store, date, slot),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [info, ?state].join(' · '),
                    style: tt.labelLarge?.copyWith(color: muted, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: absence == null ? 'Отметить пропуск' : 'Снять пропуск',
                  color: muted,
                  icon: Icon(absence == null ? Icons.event_busy_outlined : Icons.event_available_rounded, size: 20),
                  onPressed: () => toggleLessonAbsence(context, store, date, slot),
                ),
              ],
            ),
            for (final subject in slot.subjects) ...[
              Text(
                store.subjectName(subject),
                style: tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.12),
              ),
              for (final entry in slot.entries.where((e) => e.subject == subject))
                if (entry.room.isNotEmpty || entry.teacher.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      [roomText(entry.room), entry.teacher].where((x) => x.isNotEmpty).join(' · '),
                      style: tt.bodyMedium?.copyWith(color: muted),
                    ),
                  ),
            ],
            if (mark != null || absence != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (mark != null) Pill(mark.label, tone: chip, icon: Icons.bookmark_rounded),
                    if (absence != null)
                      Pill(
                        '${absence.hours} ч · ${absence.excused ? 'по уважительной' : 'без уважительной'}',
                        tone: absenceTone(context, excused: absence.excused),
                        icon: Icons.event_busy_outlined,
                      ),
                  ],
                ),
              ),
            if (absence != null && absence.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(absence.note, style: tt.bodyMedium?.copyWith(color: fg)),
              ),
            if (bell != null && bell.hasBreak)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${bell.lunchInside ? 'Обед' : 'Перерыв'} · ${shortRange(bell.breakStart!, bell.breakEnd!)}',
                  style: tt.labelMedium?.copyWith(color: muted),
                ),
              ),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      task.done
                          ? Icons.check_circle_outline_rounded
                          : (task.homework ? Icons.menu_book_rounded : Icons.sticky_note_2_rounded),
                      size: 18,
                      color: muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${task.homework ? 'Задание' : 'Заметка'} · до ${shortDate(task.due)}${task.done ? ' · выполнено' : ''}',
                            style: tt.labelMedium?.copyWith(color: muted),
                          ),
                          Text(
                            task.text,
                            style: tt.bodyMedium?.copyWith(
                              color: fg,
                              decoration: task.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
