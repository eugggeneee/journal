import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../app/scope.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/pickers.dart';
import '../kit/sheets/sheet.dart';

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

  /// Превью: большая оценка, предмет и дата — меняют цвет вместе с выбранной оценкой.
  Widget _preview(BuildContext context, AppStore store) {
    final cs = context.cs;
    final v = value;
    final tone = v == null ? neutralTone(context) : gradeTone(context, v);
    final accent = v == null ? cs.surfaceContainerLow : gradeAccent(context, v);
    final onAccent = v == null ? cs.onSurfaceVariant : onColorFor(accent);
    final details = [dayCaption(date), if (kind.isNotEmpty) kind].join(' · ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: accent,
            shape: const StarBorder(points: 10, innerRadiusRatio: 0.86, pointRounding: 0.55, valleyRounding: 0.4),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: Text(
              v == null ? '–' : '$v',
              key: ValueKey(v),
              style: TextStyle(fontSize: v == 10 ? 26 : 30, fontWeight: FontWeight.w800, color: onAccent, height: 1),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              subject.isEmpty ? 'Предмет не выбран' : store.subjectName(subject),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.tt.titleMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.bodyMedium?.copyWith(color: tone.fg.withValues(alpha: 0.85)),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sched = store.cachedSchedule(store.settings.group, date);
    final suggested = <String>[if (sched != null) for (final s in sched.slots) ...s.subjects];
    final editing = widget.edit != null;

    final headTone = value == null ? Tone(context.cs.primaryContainer, context.cs.onPrimaryContainer) : gradeTone(context, value!);

    return SheetScaffold(
      title: editing ? 'Изменить оценку' : 'Новая оценка',
      subtitle: _added > 0 ? 'Добавлено подряд: $_added' : (editing ? 'Редактирование' : 'Запись в журнал'),
      leading: CookieIcon(icon: Icons.star_rounded, size: 52, bg: headTone.bg, fg: headTone.fg),
      trailing: editing
          ? IconButton(
              tooltip: 'Удалить оценку',
              icon: Icon(Icons.delete_outline_rounded, color: context.cs.error),
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
                  child: Text(
                    subject.isEmpty && value == null ? 'Выберите оценку и предмет' : (subject.isEmpty ? 'Выберите предмет' : 'Выберите оценку'),
                    style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                  ),
                ),
        ),
        Row(children: [
          if (!editing) ...[
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.library_add_rounded, size: 20),
                onPressed: _canSave ? () => _commit(another: true) : null,
                label: const Text('Ещё одну'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: editing ? 1 : 2,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded, size: 22),
              onPressed: _canSave ? () => _commit(another: false) : null,
              label: Text(editing ? 'Готово' : 'Сохранить'),
            ),
          ),
        ]),
      ]),
      children: [
        _preview(context, store),
        const FieldLabel('Оценка', top: 20),
        GradePad(value: value, onChanged: (v) => setState(() => value = v)),
        const SizedBox(height: 20),
        SubjectPicker(selected: subject, suggested: suggested, onSelect: (s) => setState(() => subject = s)),
        const SizedBox(height: 12),
        KindPicker(kind: kind, kinds: _kinds, onChanged: (k) => setState(() => kind = k)),
        FieldLabel('Дата', trailing: dayCaption(date)),
        DayChips(date: date, onChanged: (d) => setState(() => date = d)),
        const SizedBox(height: 20),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Заметка',
            hintText: 'Необязательно — например, «ответ у доски»',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}
