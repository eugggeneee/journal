import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/pickers.dart';
import '../kit/sheets/sheet.dart';

/// Пометка к дате: «ОКР», «Зачёт», «Практика» или своя. Можно на весь день или на конкретную пару —
/// и на любую дату, даже если расписания на неё нет.
Future<void> showMarkSheet(BuildContext context, DateTime date, {int? lesson, DayMark? edit}) =>
    showAdaptiveSheet<void>(context, (_) => _MarkSheet(date: date, lesson: lesson, edit: edit));

IconData markIcon(String label) => label == kShortDayMark ? Icons.timelapse_rounded : Icons.bookmark_rounded;

Tone markTone(BuildContext context) => Tone(context.cs.tertiaryContainer, context.cs.onTertiaryContainer);

class _MarkSheet extends StatefulWidget {
  const _MarkSheet({required this.date, this.lesson, this.edit});
  final DateTime date;
  final int? lesson;
  final DayMark? edit;
  @override
  State<_MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends State<_MarkSheet> {
  late DateTime date = widget.edit?.date ?? widget.date;
  late int lesson = widget.edit?.lesson ?? widget.lesson ?? 0;
  late bool custom = widget.edit != null && !kMarkPresets.contains(widget.edit!.label);
  late String preset = (widget.edit != null && !custom) ? widget.edit!.label : kMarkPresets.first;
  late final TextEditingController _c = TextEditingController(text: custom ? widget.edit!.label : '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get label => custom ? _c.text.trim() : preset;

  void _save() {
    final text = label;
    if (text.isEmpty) return;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final edit = widget.edit;
    final beforeNew = store.snapshotMarks(date);
    final beforeOld = (edit != null && !sameDay(edit.date, date)) ? store.snapshotMarks(edit.date) : null;
    store.saveMark(DayMark(id: edit?.id ?? newId(), date: date, lesson: lesson, label: text));
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(messenger, edit == null ? 'Пометка добавлена · $text' : 'Пометка изменена', () {
      store.restoreMarks(date, beforeNew);
      if (beforeOld != null) store.restoreMarks(edit!.date, beforeOld);
    });
  }

  void _delete() {
    final m = widget.edit!;
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final before = store.snapshotMarks(m.date);
    store.deleteMark(m.id);
    Haptics.medium();
    Navigator.of(context).pop();
    showUndo(messenger, 'Пометка удалена', () => store.restoreMarks(m.date, before));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final tone = markTone(context);
    final editing = widget.edit != null;
    final existing = store.markFor(date, lesson);
    final replaces = existing != null && existing.id != widget.edit?.id;
    final sched = store.cachedSchedule(store.settings.group, date);
    String? lessonName;
    if (lesson > 0 && sched != null) {
      for (final s in sched.slots) {
        if (s.number == lesson) lessonName = s.subjects.map(store.subjectName).join(' / ');
      }
    }

    return SheetScaffold(
      title: editing ? 'Изменить пометку' : 'Новая пометка',
      subtitle: dayCaption(date),
      leading: CookieIcon(icon: Icons.bookmark_rounded, size: 52, bg: tone.bg, fg: tone.fg),
      trailing: editing
          ? IconButton(
              tooltip: 'Удалить пометку',
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              onPressed: _delete,
            )
          : null,
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 22),
          onPressed: label.isEmpty ? null : _save,
          label: Text(editing ? 'Готово' : 'Сохранить'),
        ),
      ),
      children: [
        FieldLabel('Дата', top: 8, trailing: dayCaption(date)),
        DayChips(date: date, onChanged: (d) => setState(() => date = d)),
        const FieldLabel('Что это'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in kMarkPresets)
            ChoiceTag(
              label: p,
              icon: p == kShortDayMark ? Icons.timelapse_rounded : Icons.bookmark_outline_rounded,
              selected: !custom && preset == p,
              onTap: () => setState(() {
                custom = false;
                preset = p;
                // «Сокращённый день» — всегда пометка на весь день
                if (p == kShortDayMark) lesson = 0;
              }),
            ),
          ChoiceTag(
            label: 'Своя',
            icon: Icons.edit_rounded,
            selected: custom,
            onTap: () => setState(() => custom = true),
          ),
        ]),
        Smooth(
          child: custom
              ? Padding(
                  key: const ValueKey('custom'),
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _c,
                    autofocus: widget.edit == null || !kMarkPresets.contains(widget.edit!.label),
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(24)],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Название пометки',
                      hintText: 'Например, Консультация',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('custom-none')),
        ),
        const FieldLabel('К чему относится'),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ChoiceTag(
            label: 'Весь день',
            icon: Icons.today_rounded,
            selected: lesson == 0,
            onTap: () => setState(() => lesson = 0),
          ),
          for (var n = 1; n <= kMaxPairs; n++)
            ChoiceSquare(
              label: '$n',
              semantics: '$n пара',
              size: 44,
              selected: lesson == n,
              marked: store.markFor(date, n) != null,
              tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
              accent: cs.primary,
              onTap: () => setState(() => lesson = n),
            ),
        ]),
        Smooth(
          child: (lessonName != null || replaces)
              ? Padding(
                  key: ValueKey('hint-$lesson-$replaces'),
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Text(
                    [
                      if (lessonName != null) '$lesson пара: $lessonName',
                      if (replaces) 'Прежняя пометка «${existing.label}» заменится.',
                    ].join('\n'),
                    style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('hint-none')),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Маленькая плашка с названием пометки: садится на нижний край номера пары, размер карточки не меняется.
class MarkTag extends StatelessWidget {
  const MarkTag({super.key, required this.label, required this.ringColor});
  final String label;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final tone = markTone(context);
    return Semantics(
      label: 'Пометка: $label',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 62),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ringColor, width: 2),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tone.fg, height: 1.2),
        ),
      ),
    );
  }
}

/// Пометки дня: на весь день и на пары, которых нет в расписании (или расписания нет совсем).
/// Пометки на пары из расписания видны плашкой на самой карточке пары.
class MarksSection extends StatelessWidget {
  const MarksSection({super.key, required this.date, required this.store, required this.slots});
  final DateTime date;
  final AppStore store;
  final List<LessonSlot> slots;

  @override
  Widget build(BuildContext context) {
    final numbers = {for (final s in slots) s.number};
    final list = [for (final m in store.marksOn(date)) if (m.wholeDay || !numbers.contains(m.lesson)) m];
    return Smooth(
      child: list.isEmpty
          ? const SizedBox(key: ValueKey('marks-none'), width: double.infinity)
          : Padding(
              key: ValueKey('marks-${list.map((m) => m.id).join(',')}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(children: [
                for (var i = 0; i < list.length; i++) _MarkTile(mark: list[i], store: store, index: i, count: list.length),
              ]),
            ),
    );
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({required this.mark, required this.store, required this.index, required this.count});
  final DayMark mark;
  final AppStore store;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tone = markTone(context);
    final m = mark;
    return SegmentCard(
      index: index,
      count: count,
      color: tone.bg.withValues(alpha: 0.55),
      dismissKey: ValueKey('mark-${m.id}'),
      onDelete: () {
        final messenger = ScaffoldMessenger.of(context);
        final before = store.snapshotMarks(m.date);
        store.deleteMark(m.id);
        Haptics.medium();
        showUndo(messenger, 'Пометка удалена', () => store.restoreMarks(m.date, before));
      },
      onTap: () => showMarkSheet(context, m.date, edit: m),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(46 * 0.34)),
            child: Icon(markIcon(m.label), color: tone.fg, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                m.wholeDay ? 'Весь день' : '${m.lesson} пара',
                style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}
