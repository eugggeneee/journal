import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';

/// Добавление и правка пропусков.
///
/// Если расписание дня известно — можно отметить сразу несколько пар. Иначе (или по кнопке
/// «Указать вручную») — одна запись с номером пары и предметом.
Future<void> showAbsenceSheet(BuildContext context, {Absence? edit, DateTime? date, int? lesson}) =>
    showAdaptiveSheet<void>(context, (_) => _AbsenceForm(edit: edit, date: date, lesson: lesson));

class _AbsenceForm extends StatefulWidget {
  const _AbsenceForm({this.edit, this.date, this.lesson});
  final Absence? edit;
  final DateTime? date;
  final int? lesson;
  @override
  State<_AbsenceForm> createState() => _AbsenceFormState();
}

class _AbsenceFormState extends State<_AbsenceForm> {
  late DateTime date = widget.edit?.date ?? widget.date ?? today();
  late int hours = widget.edit?.hours ?? StoreScope.of(context).settings.absenceHours;
  late bool excused = widget.edit?.excused ?? false;
  late final TextEditingController note = TextEditingController(text: widget.edit?.note ?? '');

  // режим «из расписания»
  late final Set<int> picked = {if (widget.edit == null && (widget.lesson ?? 0) > 0) widget.lesson!};
  // режим «вручную»
  late bool forceManual = widget.edit != null;
  late int manualLesson = widget.edit?.lesson ?? 0;
  late String manualSubject = widget.edit?.subject ?? '';

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  DaySchedule? _schedule() {
    final store = StoreScope.of(context);
    final s = store.cachedSchedule(store.settings.group, date);
    return (s == null || s.slots.isEmpty) ? null : s;
  }

  bool _manual(DaySchedule? s) => forceManual || s == null;

  bool _canSave(DaySchedule? s) => _manual(s) ? manualSubject.isNotEmpty : picked.isNotEmpty;

  void _save(DaySchedule? sched) {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final edit = widget.edit;
    final beforeNew = store.snapshotDay(date);
    final beforeOld = (edit != null && !sameDay(edit.date, date)) ? store.snapshotDay(edit.date) : null;
    final text = note.text.trim();

    final List<Absence> items;
    if (_manual(sched)) {
      items = [
        Absence(
          id: edit?.id ?? newId(),
          date: date,
          lesson: manualLesson,
          subject: manualSubject,
          hours: hours,
          excused: excused,
          note: text,
        ),
      ];
    } else {
      items = [
        for (final slot in sched!.slots)
          if (picked.contains(slot.number))
            Absence(
              id: store.absenceFor(date, slot.number)?.id ?? newId(),
              date: date,
              lesson: slot.number,
              subject: slot.subject,
              hours: hours,
              excused: excused,
              note: text,
            ),
      ];
    }
    if (items.isEmpty) return;

    store.saveAbsences(items);
    Haptics.medium();
    Navigator.of(context).pop();

    final total = items.fold<int>(0, (s, a) => s + a.hours);
    final msg = items.length == 1
        ? (edit == null ? 'Пропуск добавлен · ${hoursText(total)}' : 'Пропуск изменён')
        : 'Пропуск: ${pairsText(items.length)} · ${hoursText(total)}';
    showUndo(messenger, msg, () {
      store.restoreDay(date, beforeNew);
      if (beforeOld != null) store.restoreDay(edit!.date, beforeOld);
    });
  }

  void _delete() {
    final a = widget.edit!;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final before = store.snapshotDay(a.date);
    store.deleteAbsence(a.id);
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(messenger, 'Пропуск удалён', () => store.restoreDay(a.date, before));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sched = _schedule();
    final manual = _manual(sched);
    final editing = widget.edit != null;
    final suggested = <String>[if (sched != null) for (final s in sched.slots) ...s.subjects];

    return SheetScaffold(
      title: editing ? 'Пропуск' : 'Новый пропуск',
      trailing: editing
          ? IconButton(
              tooltip: 'Удалить пропуск',
              icon: Icon(Icons.delete_outline_rounded, color: context.cs.error),
              onPressed: _delete,
            )
          : null,
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_canSave(sched))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              manual ? 'Выберите предмет' : 'Отметьте хотя бы одну пару',
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSave(sched) ? () => _save(sched) : null,
            child: Text(editing ? 'Готово' : (manual ? 'Сохранить' : _saveLabel())),
          ),
        ),
      ]),
      children: [
        FieldLabel('Дата', trailing: dayCaption(date), top: 8),
        DayChips(
          date: date,
          onChanged: (d) => setState(() {
            date = d;
            picked.clear();
          }),
        ),
        if (!manual) ..._lessonPicker(context, store, sched!) else ..._manualPicker(context, sched, suggested),
        const FieldLabel('Сколько пропущено'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('1 час')),
              ButtonSegment(value: 2, label: Text('2 часа (пара)')),
            ],
            selected: {hours},
            onSelectionChanged: (s) {
              Haptics.selection();
              setState(() => hours = s.first);
            },
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('По уважительной причине'),
          subtitle: const Text('Справка, болезнь, заявление'),
          value: excused,
          onChanged: (v) {
            Haptics.selection();
            setState(() => excused = v);
          },
        ),
        const FieldLabel('Заметка', top: 8),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Необязательно'),
        ),
      ],
    );
  }

  String _saveLabel() {
    final n = picked.length;
    if (n <= 1) return 'Сохранить';
    return 'Сохранить: ${pairsText(n)}';
  }

  List<Widget> _lessonPicker(BuildContext context, AppStore store, DaySchedule sched) {
    final allPicked = sched.slots.every((s) => picked.contains(s.number));
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Row(children: [
          Expanded(child: Text('Пары', style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          TextButton.icon(
            onPressed: () => setState(() {
              Haptics.selection();
              if (allPicked) {
                picked.clear();
              } else {
                picked.addAll(sched.slots.map((s) => s.number));
              }
            }),
            icon: Icon(allPicked ? Icons.deselect_rounded : Icons.done_all_rounded, size: 18),
            label: Text(allPicked ? 'Снять все' : 'Весь день'),
          ),
        ]),
      ),
      for (final slot in sched.slots) _lessonTile(context, store, slot),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => forceManual = true),
          child: const Text('Нет в списке? Указать вручную'),
        ),
      ),
    ];
  }

  Widget _lessonTile(BuildContext context, AppStore store, LessonSlot slot) {
    final cs = context.cs;
    final on = picked.contains(slot.number);
    final existing = store.absenceFor(date, slot.number);
    final names = slot.subjects.map(store.subjectName).join(' / ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: on ? cs.secondaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            Haptics.selection();
            if (on) {
              picked.remove(slot.number);
            } else {
              picked.add(slot.number);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              NumberBadge('${slot.number}', size: 38, round: false, tone: Tone(on ? cs.secondary : cs.primaryContainer, on ? cs.onSecondary : cs.onPrimaryContainer)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(names, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (existing != null)
                    Text(
                      'Уже отмечено: ${hoursText(existing.hours)} — заменится',
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? cs.secondary : cs.outline),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _manualPicker(BuildContext context, DaySchedule? sched, List<String> suggested) => [
        const FieldLabel('Пара'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceTag(label: 'Не указана', selected: manualLesson == 0, onTap: () => setState(() => manualLesson = 0)),
          for (var n = 1; n <= 8; n++)
            ChoiceTag(
              label: '$n',
              selected: manualLesson == n,
              onTap: () => setState(() {
                manualLesson = n;
                if (sched != null) {
                  final hit = sched.slots.where((s) => s.number == n);
                  if (hit.isNotEmpty) manualSubject = hit.first.subject;
                }
              }),
            ),
        ]),
        const FieldLabel('Предмет'),
        SubjectPicker(selected: manualSubject, suggested: suggested, onSelect: (s) => setState(() => manualSubject = s)),
        if (sched != null && widget.edit == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => forceManual = false),
              child: const Text('Выбрать пары из расписания'),
            ),
          ),
      ];
}
