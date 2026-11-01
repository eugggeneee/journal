import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../data/models.dart';
import '../absences/absence_sheet.dart';
import '../grades/grade_sheet.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/sheet.dart';
import '../scope.dart';

/// Действия с парой: пропуск (1/2 часа, уважительный), снять пропуск, добавить оценку.
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final slot = widget.slot;
    final date = widget.date;
    final cs = context.cs;
    final absence = store.absenceFor(date, slot.number);
    final defHours = store.settings.absenceHours;
    final multi = slot.subjects.length > 1;
    final current = absence?.subject ?? subject;

    void mark(int hours) {
      Haptics.medium();
      store.saveAbsence(Absence(
        id: absence?.id ?? newId(),
        date: date,
        lesson: slot.number,
        subject: current,
        hours: hours,
        excused: absence?.excused ?? false,
        note: absence?.note ?? '',
      ));
    }

    void remove() {
      final m = ScaffoldMessenger.of(context);
      final before = store.snapshotDay(date);
      store.deleteAbsence(absence!.id);
      Haptics.light();
      Navigator.of(context).pop();
      showUndo(m, 'Пропуск снят', () => store.restoreDay(date, before));
    }

    final info = <Widget>[
      for (final e in slot.entries)
        if (e.room.isNotEmpty || e.teacher.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.meeting_room_rounded, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if (e.room.isNotEmpty) (RegExp(r'\d').hasMatch(e.room) ? 'ауд. ${e.room}' : e.room),
                    if (e.teacher.isNotEmpty) e.teacher,
                  ].join(' · '),
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ]),
          ),
    ];

    return SheetScaffold(
      title: slot.subjects.map(store.subjectName).join(' / '),
      subtitle: '${slot.number} пара · ${dayCaption(date)}',
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
        if (multi && absence == null) ...[
          const FieldLabel('Какой предмет?', top: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in slot.subjects)
              ChoiceTag(label: store.subjectName(s), selected: s == subject, onTap: () => setState(() => subject = s)),
          ]),
        ],
        const FieldLabel('Пропуск', top: 16),
        if (absence == null)
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.event_busy_rounded),
                label: Text(defHours == 2 ? 'Пара · 2 ч' : '1 час'),
                onPressed: () => mark(defHours),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => mark(defHours == 2 ? 1 : 2),
                child: Text(defHours == 2 ? 'Только 1 час' : 'Вся пара · 2 ч'),
              ),
            ),
          ])
        else ...[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 1, label: Text('1 час')),
                ButtonSegment(value: 2, label: Text('2 часа')),
              ],
              selected: {absence.hours},
              onSelectionChanged: (s) => mark(s.first),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('По уважительной причине'),
            value: absence.excused,
            onChanged: (v) {
              Haptics.selection();
              store.saveAbsence(absence.copyWith(excused: v));
            },
          ),
          Row(children: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Снять пропуск'),
              onPressed: remove,
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                final host = Navigator.of(context).context;
                Navigator.of(context).pop();
                showAbsenceSheet(host, edit: absence);
              },
              child: const Text('Подробнее'),
            ),
          ]),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}
