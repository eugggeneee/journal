import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/sheet.dart';
import '../scope.dart';

const _kinds = ['Ответ', 'Контрольная', 'Лабораторная', 'Практическая', 'Самостоятельная', 'Тест', 'Зачёт', 'Экзамен'];

/// Добавление и правка оценки.
Future<void> showGradeSheet(BuildContext context, {Grade? edit, String? subject, DateTime? date}) =>
    showAdaptiveSheet<void>(context, (_) => _GradeForm(edit: edit, subject: subject, date: date));

class _GradeForm extends StatefulWidget {
  const _GradeForm({this.edit, this.subject, this.date});
  final Grade? edit;
  final String? subject;
  final DateTime? date;
  @override
  State<_GradeForm> createState() => _GradeFormState();
}

class _GradeFormState extends State<_GradeForm> {
  late String subject = widget.edit?.subject ?? widget.subject ?? '';
  late int? value = widget.edit?.value;
  late DateTime date = widget.edit?.date ?? widget.date ?? today();
  late String kind = widget.edit?.kind ?? '';
  late final TextEditingController note = TextEditingController(text: widget.edit?.note ?? '');
  int _added = 0;

  bool get _canSave => subject.isNotEmpty && value != null;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void _commit({required bool another}) {
    if (!_canSave) return;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final old = widget.edit;
    final g = Grade(
      id: old?.id ?? newId(),
      subject: subject,
      value: value!,
      date: date,
      kind: kind,
      note: note.text.trim(),
    );
    store.saveGrade(g);
    Haptics.medium();
    final what = '${g.value} · ${store.subjectName(g.subject)}';
    if (another) {
      setState(() {
        value = null;
        note.clear();
        _added++;
      });
      showNote(messenger, 'Добавлено: $what');
      return;
    }
    Navigator.of(context).pop();
    showUndo(
      messenger,
      old == null ? 'Оценка добавлена: $what' : 'Оценка изменена: $what',
      () => old == null ? store.deleteGrade(g.id) : store.saveGrade(old),
    );
  }

  void _delete() {
    final g = widget.edit!;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    store.deleteGrade(g.id);
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(messenger, 'Оценка удалена', () => store.saveGrade(g));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sched = store.cachedSchedule(store.settings.group, date);
    final suggested = <String>[if (sched != null) for (final s in sched.slots) ...s.subjects];
    final editing = widget.edit != null;

    return SheetScaffold(
      title: editing ? 'Оценка' : 'Новая оценка',
      subtitle: _added > 0 ? 'Добавлено подряд: $_added' : null,
      trailing: editing
          ? IconButton(
              tooltip: 'Удалить оценку',
              icon: Icon(Icons.delete_outline_rounded, color: context.cs.error),
              onPressed: _delete,
            )
          : null,
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_canSave)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              subject.isEmpty ? 'Выберите предмет и оценку' : 'Выберите оценку',
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        Row(children: [
          if (!editing) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _canSave ? () => _commit(another: true) : null,
                child: const Text('Ещё одну'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: editing ? 1 : 2,
            child: FilledButton(
              onPressed: _canSave ? () => _commit(another: false) : null,
              child: Text(editing ? 'Готово' : 'Сохранить'),
            ),
          ),
        ]),
      ]),
      children: [
        const FieldLabel('Оценка', top: 8),
        GradePad(value: value, onChanged: (v) => setState(() => value = v)),
        const FieldLabel('Предмет'),
        SubjectPicker(selected: subject, suggested: suggested, onSelect: (s) => setState(() => subject = s)),
        FieldLabel('Дата', trailing: dayCaption(date)),
        DayChips(date: date, onChanged: (d) => setState(() => date = d)),
        const FieldLabel('Тип работы'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in _kinds) ChoiceTag(label: k, selected: kind == k, onTap: () => setState(() => kind = kind == k ? '' : k)),
        ]),
        const FieldLabel('Заметка'),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Необязательно — например, «ответ у доски»'),
        ),
      ],
    );
  }
}
