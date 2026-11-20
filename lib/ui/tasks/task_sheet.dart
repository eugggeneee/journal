import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../app/scope.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/pickers.dart';
import '../kit/sheets/sheet.dart';

/// Добавление и правка задания. Если открыто с пары, задание привязывается к ней и к её предмету.
Future<void> showTaskSheet(
  BuildContext context, {
  Task? edit,
  DateTime? lessonDate,
  int lesson = 0,
  String? subject,
  bool homework = true,
}) =>
    showAdaptiveSheet<void>(
      context,
      (_) => _TaskForm(edit: edit, lessonDate: lessonDate, lesson: lesson, subject: subject, homework: homework),
    );

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.edit, this.lessonDate, this.lesson = 0, this.subject, this.homework = true});
  final Task? edit;
  final DateTime? lessonDate;
  final int lesson;
  final String? subject;
  final bool homework;
  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final TextEditingController text = TextEditingController(text: widget.edit?.text ?? '');
  late String subject = widget.edit?.subject ?? widget.subject ?? '';
  late bool homework = widget.edit?.homework ?? widget.homework;
  late DateTime due = widget.edit?.due ?? _defaultDue();

  DateTime _defaultDue() {
    final base = widget.lessonDate ?? today();
    // Домашнее задание обычно сдают к следующему дню, заметка («принести тетрадь») нужна к самой паре.
    return widget.homework ? addDays(base.isBefore(today()) ? today() : base, 1) : (base.isBefore(today()) ? today() : base);
  }

  bool get _canSave => text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _commit() {
    if (!_canSave) return;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final old = widget.edit;
    final t = Task(
      id: old?.id ?? newId(),
      text: text.text.trim(),
      due: due,
      subject: subject,
      date: old?.date ?? widget.lessonDate,
      lesson: old?.lesson ?? widget.lesson,
      homework: homework,
      done: old?.done ?? false,
    );
    store.saveTask(t);
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(
      messenger,
      old == null ? 'Задание добавлено' : 'Задание изменено',
      () => old == null ? store.deleteTask(t.id) : store.saveTask(old),
    );
  }

  void _delete() {
    final t = widget.edit!;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    store.deleteTask(t.id);
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(messenger, 'Задание удалено', () => store.saveTask(t));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final editing = widget.edit != null;
    final lessonDate = widget.edit?.date ?? widget.lessonDate;
    final lesson = widget.edit?.lesson ?? widget.lesson;
    final sched = lessonDate == null ? null : store.cachedSchedule(store.settings.group, lessonDate);
    final suggested = <String>[if (sched != null) for (final s in sched.slots) ...s.subjects];
    final t = today();
    final custom = !sameDay(due, t) && !sameDay(due, addDays(t, 1)) && !sameDay(due, addDays(t, 7));

    return SheetScaffold(
      title: editing ? 'Изменить задание' : 'Новое задание',
      subtitle: lesson > 0 && lessonDate != null ? '$lesson пара · ${shortDate(lessonDate)}' : 'Со сроком и напоминанием на главной',
      leading: IconBox(icon: homework ? Icons.menu_book_rounded : Icons.sticky_note_2_rounded, size: 52),
      trailing: editing
          ? IconButton(tooltip: 'Удалить задание', icon: Icon(Icons.delete_outline_rounded, color: iconTone(cs).fg), onPressed: _delete)
          : null,
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 22),
          onPressed: _canSave ? _commit : null,
          label: Text(editing ? 'Готово' : 'Сохранить'),
        ),
      ),
      children: [
        TextField(
          controller: text,
          autofocus: !editing,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: homework ? 'Что задано' : 'Что запомнить',
            hintText: homework ? 'Например, «параграф 5, задачи 3–7»' : 'Например, «принести тетрадь»',
            prefixIcon: const Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceTag(label: 'Домашнее задание', icon: Icons.menu_book_rounded, selected: homework, onTap: () => setState(() => homework = true)),
          ChoiceTag(label: 'Заметка', icon: Icons.sticky_note_2_rounded, selected: !homework, onTap: () => setState(() => homework = false)),
        ]),
        FieldLabel('Срок', trailing: dueLabel(due)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceTag(label: 'Сегодня', icon: Icons.today_rounded, selected: sameDay(due, t), onTap: () => setState(() => due = t)),
          ChoiceTag(label: 'Завтра', icon: Icons.event_rounded, selected: sameDay(due, addDays(t, 1)), onTap: () => setState(() => due = addDays(t, 1))),
          ChoiceTag(label: 'Через неделю', icon: Icons.date_range_rounded, selected: sameDay(due, addDays(t, 7)), onTap: () => setState(() => due = addDays(t, 7))),
          ChoiceTag(
            label: custom ? '${weekdayShort(due)}, ${shortDate(due)}' : 'Другая дата',
            icon: Icons.calendar_month_rounded,
            selected: custom,
            onTap: () async {
              final d = await pickDay(context, due);
              if (d != null) setState(() => due = dateOnly(d));
            },
          ),
        ]),
        const SizedBox(height: 20),
        SubjectPicker(selected: subject, suggested: suggested, label: 'Предмет (необязательно)', onSelect: (s) => setState(() => subject = s)),
      ],
    );
  }

  static String dueLabel(DateTime d) => '${relativeDay(d)}, ${shortDate(d)}';
}
