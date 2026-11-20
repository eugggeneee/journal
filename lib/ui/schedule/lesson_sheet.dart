import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../logic/bells.dart';
import '../absences/absence_sheet.dart';
import '../app/scope.dart';
import '../grades/grade_sheet.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/pickers.dart';
import '../kit/sheets/select_sheet.dart';
import '../kit/sheets/sheet.dart';
import '../tasks/task_sheet.dart';
import '../tasks/task_tile.dart';
import 'marks.dart';

/// Действия с парой: пропуск (причина и часы), снять пропуск, добавить оценку.
Future<void> showLessonSheet(BuildContext context, DateTime date, LessonSlot slot) =>
    showAdaptiveSheet<void>(context, (_) => _LessonSheet(date: date, slot: slot));

class _LessonSheet extends StatefulWidget {
  const _LessonSheet({required this.date, required this.slot});
  final DateTime date;
  final LessonSlot slot;
  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet> {
  late String subject = widget.slot.subject;
  int? _hours;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final slot = widget.slot;
    final date = widget.date;
    final cs = context.cs;
    final absence = store.absenceFor(date, slot.number);
    final hours = absence?.hours ?? _hours ?? store.settings.absenceHours;
    final multi = slot.subjects.length > 1;
    final current = absence?.subject ?? subject;

    void mark({required bool excused}) {
      Haptics.medium();
      store.saveAbsence(Absence(
        id: absence?.id ?? newId(),
        date: date,
        lesson: slot.number,
        subject: current,
        hours: hours,
        excused: excused,
        note: absence?.note ?? '',
      ));
    }

    void setHours(int h) {
      Haptics.selection();
      if (absence == null) {
        setState(() => _hours = h);
      } else {
        store.saveAbsence(absence.copyWith(hours: h));
      }
    }

    void remove() {
      final m = ScaffoldMessenger.of(context);
      final before = store.snapshotDay(date);
      store.deleteAbsence(absence!.id);
      Haptics.light();
      Navigator.of(context).pop();
      showUndo(m, 'Пропуск снят', () => store.restoreDay(date, before));
    }

    final bell = store.bellFor(date, slot.number);
    final profile = store.bellProfileFor(date);
    final dayMark = store.markFor(date, slot.number);
    final gap = bell == null ? null : gapLabel(profile, slot.number);
    final lessonTasks = store.tasksForLesson(date, slot.number);

    final info = <Widget>[
      if (bell != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.schedule_rounded, size: 20, color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slotRange(bell), style: context.tt.bodyLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500)),
                if (bell.hasBreak)
                  Text(
                    'Две половины ${halvesText(bell)}: ${fmtMin(bell.start)}–${fmtMin(bell.breakStart!)} и ${fmtMin(bell.breakEnd!)}–${fmtMin(bell.end)}, между ними ${innerBreakWord(bell)} ${minText(bell.breakMinutes)}',
                    style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (gap != null) Text('После пары: ${gap.toLowerCase()}', style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      for (final e in slot.entries)
        if (e.room.isNotEmpty || e.teacher.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.meeting_room_rounded, size: 20, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  [
                    if (e.room.isNotEmpty) (RegExp(r'\d').hasMatch(e.room) ? 'ауд. ${e.room}' : e.room),
                    if (e.teacher.isNotEmpty) e.teacher,
                  ].join(' · '),
                  style: context.tt.bodyLarge?.copyWith(color: cs.onSurface),
                ),
              ),
            ]),
          ),
    ];

    final tone = neutralTone(context);

    return SheetScaffold(
      title: slot.subjects.map(store.subjectName).join(' / '),
      subtitle: '${slot.number} пара · ${dayCaption(date)}',
      leading: NumberBadge('${slot.number}', tone: tone, size: 52, round: false),
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.star_rounded),
          label: const Text('Добавить оценку по предмету'),
          onPressed: () {
            final host = Navigator.of(context).context;
            Navigator.of(context).pop();
            showGradeSheet(host, subject: current, date: date);
          },
        ),
      ),
      children: [
        ...info,
        Smooth(
          child: (multi && absence == null)
              ? Column(
                  key: const ValueKey('subject-pick'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Какой предмет?', top: 12),
                    ChoiceList<String>(
                      options: [for (final s in slot.subjects) MenuOption(s, store.subjectName(s))],
                      value: subject,
                      onChanged: (s) => setState(() => subject = s),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('subject-none')),
        ),
        FieldLabel(absence == null ? 'Отметить пропуск' : 'Пропуск', top: 16, trailing: absence == null ? null : hoursText(absence.hours)),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('1 час')),
              ButtonSegment(value: 2, label: Text('2 часа (пара)')),
            ],
            selected: {hours},
            onSelectionChanged: (s) => setHours(s.first),
          ),
        ),
        const SizedBox(height: 12),
        ExcuseChoices(selected: absence?.excused, onChoice: (value) => mark(excused: value)),
        Smooth(
          child: absence != null
              ? Padding(
                  key: const ValueKey('absence-actions'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Снять пропуск'),
                      onPressed: remove,
                    ),
                    TextButton(
                      onPressed: () {
                        final host = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        showAbsenceForm(host, edit: absence);
                      },
                      child: const Text('Подробнее'),
                    ),
                  ]),
                )
              : const SizedBox.shrink(key: ValueKey('absence-none')),
        ),
        const FieldLabel('Пометка', top: 16),
        Row(children: [
          Expanded(
            child: dayMark == null
                ? Text('ОКР, зачёт, практика или своя', style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: MarkPill(dayMark),
                  ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            icon: Icon(dayMark == null ? Icons.bookmark_add_outlined : Icons.edit_outlined, size: 20),
            label: Text(dayMark == null ? 'Добавить' : 'Изменить'),
            onPressed: () {
              final host = Navigator.of(context).context;
              Navigator.of(context).pop();
              showMarkSheet(host, date, lesson: slot.number, edit: dayMark);
            },
          ),
        ]),
        FieldLabel('Задания', top: 16, trailing: lessonTasks.isEmpty ? null : '${lessonTasks.length}'),
        for (final t in lessonTasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(borderRadius: BorderRadius.circular(JournalLayout.panelRadius),
              onTap: () {
                final host = Navigator.of(context).context;
                Navigator.of(context).pop();
                showTaskSheet(host, edit: t);
              },
              child: TaskSummary(task: t, store: store)),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final hw in const [true, false])
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
              icon: Icon(hw ? Icons.menu_book_rounded : Icons.sticky_note_2_rounded, size: 20),
              label: Text(hw ? 'Домашнее задание' : 'Заметка'),
              onPressed: () {
                final host = Navigator.of(context).context;
                Navigator.of(context).pop();
                showTaskSheet(host, lessonDate: date, lesson: slot.number, subject: current, homework: hw);
              },
            ),
        ]),
        const SizedBox(height: 4),
      ],
    );
  }
}
