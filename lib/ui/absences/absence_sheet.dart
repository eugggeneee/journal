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

/// Кнопка «Пропуск»: правка существующего — полная форма, новый — быстрая шторка.
Future<void> showAbsenceSheet(BuildContext context, {Absence? edit, DateTime? date, int? lesson}) {
  if (edit != null) return showAbsenceForm(context, edit: edit);
  return showAdaptiveSheet<void>(context, (_) => _QuickAbsence(date: date ?? today(), lesson: lesson));
}

/// Быстрая шторка для одной пары из расписания.
Future<void> showLessonAbsence(BuildContext context, DateTime date, LessonSlot slot) =>
    showAdaptiveSheet<void>(context, (_) => _QuickAbsence(date: date, fixedSlots: [slot]));

/// Быстрая шторка для всего дня.
Future<void> showWholeDayAbsence(BuildContext context, DateTime date, List<LessonSlot> slots) =>
    showAdaptiveSheet<void>(context, (_) => _QuickAbsence(date: date, fixedSlots: slots, wholeDay: true));

/// Полная форма: дата, пара, предмет, часы, причина и заметка.
Future<void> showAbsenceForm(BuildContext context, {Absence? edit, DateTime? date, int? lesson, String? subject}) =>
    showAdaptiveSheet<void>(context, (_) => _AbsenceForm(edit: edit, date: date, lesson: lesson, subject: subject));

// ═════════════════════════ быстрая шторка ═════════════════════════

/// Маленькая шторка: выбрали «без уважительной» или «по уважительной» — пропуск сразу сохранён.
class _QuickAbsence extends StatefulWidget {
  const _QuickAbsence({required this.date, this.fixedSlots, this.wholeDay = false, this.lesson});
  final DateTime date;

  /// Если задано — пары уже известны (нажали на пару или «Весь день»), выбор пар скрыт.
  final List<LessonSlot>? fixedSlots;
  final bool wholeDay;
  final int? lesson;

  @override
  State<_QuickAbsence> createState() => _QuickAbsenceState();
}

class _QuickAbsenceState extends State<_QuickAbsence> {
  late DateTime date = widget.date;
  late int hours = StoreScope.of(context).settings.absenceHours;
  bool whole = true;
  final Set<int> picked = {};
  String manualSubject = '';
  String? subjectPick;

  bool get _locked => widget.fixedSlots != null;

  @override
  void initState() {
    super.initState();
    final n = widget.lesson ?? 0;
    if (!_locked && n > 0) {
      whole = false;
      picked.add(n);
    }
  }

  DaySchedule? _schedule() {
    final store = StoreScope.of(context);
    final s = store.cachedSchedule(store.settings.group, date);
    return (s == null || s.slots.isEmpty) ? null : s;
  }

  /// Какие пары будут отмечены. null — расписания нет, нужен предмет вручную.
  List<LessonSlot>? _slots(DaySchedule? sched) {
    if (_locked) return widget.fixedSlots;
    if (sched == null) return null;
    if (whole) return sched.slots;
    return [for (final s in sched.slots) if (picked.contains(s.number)) s];
  }

  bool _canSave(List<LessonSlot>? slots) => slots != null ? slots.isNotEmpty : manualSubject.isNotEmpty;

  String _subjectFor(LessonSlot s) {
    final pick = subjectPick;
    final fixed = widget.fixedSlots;
    if (pick != null && fixed != null && fixed.length == 1 && s.subjects.contains(pick)) return pick;
    return s.subject;
  }

  void _commit(bool excused, DaySchedule? sched) {
    final slots = _slots(sched);
    if (!_canSave(slots)) return;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final before = store.snapshotDay(date);

    final items = <Absence>[];
    if (slots != null) {
      for (final s in slots) {
        final old = store.absenceFor(date, s.number);
        items.add(Absence(
          id: old?.id ?? newId(),
          date: date,
          lesson: s.number,
          subject: _subjectFor(s),
          hours: hours,
          excused: excused,
          note: old?.note ?? '',
        ));
      }
    } else {
      items.add(Absence(id: newId(), date: date, lesson: 0, subject: manualSubject, hours: hours, excused: excused));
    }

    store.saveAbsences(items);
    Haptics.medium();
    Navigator.of(context).pop();

    final total = items.fold<int>(0, (sum, a) => sum + a.hours);
    final kind = excused ? 'по уважительной' : 'без уважительной';
    final msg = items.length == 1
        ? 'Пропуск: ${hoursText(total)} · $kind'
        : 'Пропуск: ${pairsText(items.length)} · ${hoursText(total)} · $kind';
    showUndo(messenger, msg, () => store.restoreDay(date, before));
  }

  void _openDetails() {
    final host = Navigator.of(context).context;
    final d = date;
    int? lesson;
    String? subject;
    final fixed = widget.fixedSlots;
    if (fixed != null && fixed.length == 1) {
      lesson = fixed.first.number;
      subject = _subjectFor(fixed.first);
    } else if (!_locked && !whole && picked.length == 1) {
      lesson = picked.first;
    }
    Navigator.of(context).pop();
    showAbsenceForm(host, date: d, lesson: lesson, subject: subject);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sched = _locked ? null : _schedule();
    final slots = _slots(sched);
    final manual = !_locked && sched == null;
    final canSave = _canSave(slots);
    final redTone = absenceTone(context, excused: false);

    final fixed = widget.fixedSlots;
    final single = fixed != null && fixed.length == 1 ? fixed.first : null;
    String title;
    String? subtitle;
    if (single != null) {
      title = single.subjects.map(store.subjectName).join(' / ');
      subtitle = '${single.number} пара · ${dayCaption(date)}';
    } else if (widget.wholeDay) {
      title = 'Пропуск всего дня';
      subtitle = '${dayCaption(date)} · ${pairsText(fixed!.length)}';
    } else {
      title = 'Новый пропуск';
      subtitle = 'Выберите причину — пропуск сохранится сразу';
    }

    final already = slots == null ? 0 : slots.where((s) => store.absenceFor(date, s.number) != null).length;
    final totalHours = (slots?.length ?? 1) * hours;

    return SheetScaffold(
      title: title,
      subtitle: subtitle,
      leading: CookieIcon(icon: Icons.event_busy_rounded, size: 52, bg: redTone.bg, fg: redTone.fg),
      footer: Row(children: [
        Expanded(child: ExcuseTile(excused: false, enabled: canSave, onTap: () => _commit(false, sched))),
        const SizedBox(width: 12),
        Expanded(child: ExcuseTile(excused: true, enabled: canSave, onTap: () => _commit(true, sched))),
      ]),
      children: [
        if (!_locked) ...[
          FieldLabel('Дата', trailing: dayCaption(date), top: 8),
          DayChips(
            date: date,
            onChanged: (d) => setState(() {
              date = d;
              whole = true;
              picked.clear();
              manualSubject = '';
            }),
          ),
        ],
        if (!_locked && sched != null) ..._scope(context, store, sched),
        if (manual) ...[
          const SizedBox(height: 16),
          SubjectPicker(selected: manualSubject, onSelect: (s) => setState(() => manualSubject = s)),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'На эту дату расписания нет — укажите предмет.',
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        ],
        if (single != null && single.subjects.length > 1) ...[
          const FieldLabel('Какой предмет?', top: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in single.subjects)
              ChoiceTag(
                label: store.subjectName(s),
                selected: (subjectPick ?? single.subject) == s,
                onTap: () => setState(() => subjectPick = s),
              ),
          ]),
        ],
        FieldLabel('Сколько часов', trailing: (slots != null && slots.length > 1) ? 'всего ${hoursText(totalHours)}' : null, top: _locked && !(single != null && single.subjects.length > 1) ? 8 : 20),
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
        if (already > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: context.cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  already == 1 ? 'Одна из пар уже отмечена — отметка заменится.' : 'Часть пар уже отмечена — их отметки заменятся.',
                  style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                ),
              ),
            ]),
          ),
        if (!widget.wholeDay)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _openDetails,
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: const Text('Подробнее: пара, предмет, заметка'),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _scope(BuildContext context, AppStore store, DaySchedule sched) {
    final cs = context.cs;
    final names = [
      for (final s in sched.slots)
        if (picked.contains(s.number)) store.subjectName(s.subject),
    ].join(', ');
    return [
      const FieldLabel('Что пропустили'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceTag(
          label: 'Весь день · ${pairsText(sched.slots.length)}',
          icon: Icons.today_rounded,
          selected: whole,
          onTap: () => setState(() {
            whole = true;
            picked.clear();
          }),
        ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final s in sched.slots)
          ChoiceSquare(
            label: '${s.number}',
            semantics: '${s.number} пара',
            size: 52,
            selected: !whole && picked.contains(s.number),
            marked: store.absenceFor(date, s.number) != null,
            tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
            accent: cs.primary,
            onTap: () => setState(() {
              if (whole) {
                whole = false;
                picked
                  ..clear()
                  ..add(s.number);
              } else if (picked.contains(s.number)) {
                picked.remove(s.number);
                if (picked.isEmpty) whole = true;
              } else {
                picked.add(s.number);
              }
            }),
          ),
      ]),
      if (!whole && names.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(names, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),
    ];
  }
}

// ═════════════════════════ полная форма ═════════════════════════

class _AbsenceForm extends StatefulWidget {
  const _AbsenceForm({this.edit, this.date, this.lesson, this.subject});
  final Absence? edit;
  final DateTime? date;
  final int? lesson;
  final String? subject;
  @override
  State<_AbsenceForm> createState() => _AbsenceFormState();
}

class _AbsenceFormState extends State<_AbsenceForm> {
  late DateTime date = widget.edit?.date ?? widget.date ?? today();
  late int hours = widget.edit?.hours ?? StoreScope.of(context).settings.absenceHours;
  late bool excused = widget.edit?.excused ?? false;
  late final TextEditingController note = TextEditingController(text: widget.edit?.note ?? '');
  late int lesson = widget.edit?.lesson ?? widget.lesson ?? 0;
  late String subject = widget.edit?.subject ?? widget.subject ?? '';

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

  bool get _canSave => subject.isNotEmpty || widget.edit != null;

  void _save() {
    if (!_canSave) return;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final edit = widget.edit;
    final beforeNew = store.snapshotDay(date);
    final beforeOld = (edit != null && !sameDay(edit.date, date)) ? store.snapshotDay(edit.date) : null;

    store.saveAbsence(Absence(
      id: edit?.id ?? newId(),
      date: date,
      lesson: lesson,
      subject: subject,
      hours: hours,
      excused: excused,
      note: note.text.trim(),
    ));
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(messenger, edit == null ? 'Пропуск добавлен · ${hoursText(hours)}' : 'Пропуск изменён', () {
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
    final cs = context.cs;
    final sched = _schedule();
    final editing = widget.edit != null;
    final suggested = <String>[if (sched != null) for (final s in sched.slots) ...s.subjects];
    final tone = absenceTone(context, excused: excused);

    return SheetScaffold(
      title: editing ? 'Изменить пропуск' : 'Новый пропуск',
      subtitle: 'Подробная форма',
      leading: CookieIcon(icon: excused ? Icons.verified_rounded : Icons.event_busy_rounded, size: 52, bg: tone.bg, fg: tone.fg),
      trailing: editing
          ? IconButton(
              tooltip: 'Удалить пропуск',
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              onPressed: _delete,
            )
          : null,
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _canSave
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Выберите предмет', style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 22),
            onPressed: _canSave ? _save : null,
            label: Text(editing ? 'Готово' : 'Сохранить'),
          ),
        ),
      ]),
      children: [
        FieldLabel('Дата', trailing: dayCaption(date), top: 8),
        DayChips(date: date, onChanged: (d) => setState(() => date = d)),
        const FieldLabel('Пара'),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ChoiceTag(label: 'Не указана', selected: lesson == 0, onTap: () => setState(() => lesson = 0)),
          for (var n = 1; n <= 8; n++)
            ChoiceSquare(
              label: '$n',
              semantics: '$n пара',
              size: 44,
              selected: lesson == n,
              tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
              accent: cs.primary,
              onTap: () => setState(() {
                lesson = n;
                final hit = sched?.slots.where((s) => s.number == n);
                if (hit != null && hit.isNotEmpty) subject = hit.first.subject;
              }),
            ),
        ]),
        const SizedBox(height: 20),
        SubjectPicker(selected: subject, suggested: suggested, onSelect: (s) => setState(() => subject = s)),
        const FieldLabel('Сколько часов'),
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
        const FieldLabel('Причина'),
        Row(children: [
          Expanded(child: ExcuseTile(excused: false, selected: !excused, onTap: () => setState(() => excused = false))),
          const SizedBox(width: 12),
          Expanded(child: ExcuseTile(excused: true, selected: excused, onTap: () => setState(() => excused = true))),
        ]),
        const SizedBox(height: 20),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Заметка',
            hintText: 'Необязательно',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}
