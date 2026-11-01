import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../scope.dart';
import 'ctx.dart';
import 'sheet.dart';

/// Чип выбора (ChoiceChip Material 3) с вибрацией.
class ChoiceTag extends StatelessWidget {
  const ChoiceTag({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 18),
        selected: selected,
        showCheckmark: false,
        selectedColor: context.cs.secondaryContainer,
        onSelected: (_) {
          Haptics.selection();
          onTap();
        },
      );
}

/// «Сегодня» / «Вчера» / выбор любой даты.
class DayChips extends StatelessWidget {
  const DayChips({super.key, required this.date, required this.onChanged});
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final y = addDays(t, -1);
    final custom = !sameDay(date, t) && !sameDay(date, y);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ChoiceTag(label: 'Сегодня', selected: sameDay(date, t), onTap: () => onChanged(t)),
      ChoiceTag(label: 'Вчера', selected: sameDay(date, y), onTap: () => onChanged(y)),
      ChoiceTag(
        label: custom ? '${weekdayShort(date)}, ${shortDate(date)}' : 'Другая дата',
        icon: Icons.calendar_month_rounded,
        selected: custom,
        onTap: () async {
          final d = await pickDay(context, date);
          if (d != null) onChanged(dateOnly(d));
        },
      ),
    ]);
  }
}

/// Выбор предмета: сначала предметы из расписания дня, затем все известные + «Другой».
class SubjectPicker extends StatelessWidget {
  const SubjectPicker({super.key, required this.selected, required this.onSelect, this.suggested = const []});
  final String selected;
  final ValueChanged<String> onSelect;
  final List<String> suggested;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final first = <String>[];
    for (final s in suggested) {
      if (!first.contains(s)) first.add(s);
    }
    final rest = <String>[];
    for (final s in store.knownSubjects()) {
      if (!first.contains(s)) rest.add(s);
    }
    if (selected.isNotEmpty && !first.contains(selected) && !rest.contains(selected)) rest.insert(0, selected);

    Widget chips(List<String> list, {bool withOther = false}) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in list) ChoiceTag(label: store.subjectName(s), selected: s == selected, onTap: () => onSelect(s)),
          if (withOther)
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Другой'),
              onPressed: () async {
                final v = await promptText(context, title: 'Новый предмет', hint: 'Название');
                if (v == null || v.trim().isEmpty) return;
                store.addExtraSubject(v.trim());
                onSelect(v.trim());
              },
            ),
        ]);

    final sub = context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (first.isNotEmpty) ...[
        Text('По расписанию', style: sub),
        const SizedBox(height: 8),
        chips(first),
        const SizedBox(height: 14),
        Text('Все предметы', style: sub),
        const SizedBox(height: 8),
      ],
      chips(rest, withOther: true),
    ]);
  }
}

/// Клавиатура оценок 1–10: выбранная кнопка превращается из «квадрата» в круг.
class GradePad extends StatelessWidget {
  const GradePad({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final size = ((c.maxWidth - gap * 4) / 5).clamp(40.0, 68.0).toDouble();
      Widget row(int from) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (var v = from; v < from + 5; v++) _GradeCell(value: v, size: size, selected: value == v, onTap: () => onChanged(v))],
          );
      return Column(children: [row(1), const SizedBox(height: gap), row(6)]);
    });
  }
}

class _GradeCell extends StatelessWidget {
  const _GradeCell({required this.value, required this.size, required this.selected, required this.onTap});
  final int value;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = gradeTone(context, value);
    final accent = gradeAccent(context, value);
    final onAccent = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark ? Colors.white : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Оценка $value',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent : tone.bg,
            borderRadius: BorderRadius.circular(selected ? size / 2 : size * 0.3),
          ),
          child: Text(
            '$value',
            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: selected ? onAccent : tone.fg),
          ),
        ),
      ),
    );
  }
}
