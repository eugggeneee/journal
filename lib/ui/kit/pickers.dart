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
      ChoiceTag(label: 'Сегодня', icon: Icons.today_rounded, selected: sameDay(date, t), onTap: () => onChanged(t)),
      ChoiceTag(label: 'Вчера', icon: Icons.history_rounded, selected: sameDay(date, y), onTap: () => onChanged(y)),
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

// ───────────────────────── выпадающее меню ─────────────────────────

/// Пункт выпадающего меню. [section] — подпись группы (появляется, когда меняется от пункта к пункту).
class MenuOption<T> {
  const MenuOption(this.value, this.label, {this.icon, this.section});
  final T value;
  final String label;
  final IconData? icon;
  final String? section;
}

/// Действие в конце меню (например, «Новый предмет…»).
class MenuAction {
  const MenuAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Поле-выпадайка Material 3: нажали — внизу появилось меню со всеми вариантами,
/// ничего не нужно листать по шторке.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.onSelected,
    this.value,
    this.valueLabel,
    this.placeholder = 'Выберите',
    this.actions = const [],
  });
  final String label;
  final IconData icon;
  final T? value;
  final String? valueLabel;
  final String placeholder;
  final List<MenuOption<T>> options;
  final List<MenuAction> actions;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 320.0;
      final maxH = (MediaQuery.sizeOf(context).height * 0.5).clamp(240.0, 440.0).toDouble();
      final itemStyle = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(w - 16, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );

      final children = <Widget>[];
      String? lastSection;
      for (final o in options) {
        if (o.section != null && o.section != lastSection) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(o.section!, style: context.tt.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          ));
        }
        lastSection = o.section;
        final selected = value != null && o.value == value;
        children.add(MenuItemButton(
          style: itemStyle.copyWith(
            backgroundColor: WidgetStatePropertyAll(selected ? cs.secondaryContainer : Colors.transparent),
          ),
          leadingIcon: o.icon == null ? null : Icon(o.icon, size: 20, color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant),
          trailingIcon: selected ? Icon(Icons.check_rounded, size: 20, color: cs.onSecondaryContainer) : null,
          onPressed: () {
            Haptics.selection();
            onSelected(o.value);
          },
          child: Text(
            o.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.tt.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.onSecondaryContainer : cs.onSurface,
            ),
          ),
        ));
      }
      if (actions.isNotEmpty) {
        if (options.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Divider(color: cs.outlineVariant),
          ));
        }
        for (final a in actions) {
          children.add(MenuItemButton(
            style: itemStyle,
            leadingIcon: Icon(a.icon, size: 20, color: cs.primary),
            onPressed: () {
              Haptics.selection();
              a.onTap();
            },
            child: Text(a.label, style: context.tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
          ));
        }
      }

      return MenuAnchor(
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8, horizontal: 8)),
          minimumSize: WidgetStatePropertyAll(Size(w, 0)),
          maximumSize: WidgetStatePropertyAll(Size(w, maxH)),
        ),
        menuChildren: children,
        builder: (context, controller, _) {
          final open = controller.isOpen;
          final has = valueLabel != null && valueLabel!.isNotEmpty;
          return Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: open ? cs.primary : Colors.transparent, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Haptics.selection();
                if (open) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(children: [
                    Icon(icon, color: has ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(label, style: context.tt.labelMedium?.copyWith(color: open ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          has ? valueLabel! : placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleMedium?.copyWith(
                            fontWeight: has ? FontWeight.w700 : FontWeight.w500,
                            color: has ? cs.onSurface : cs.onSurfaceVariant,
                          ),
                        ),
                      ]),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.arrow_drop_down_rounded, size: 32, color: cs.onSurfaceVariant),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Выбор предмета: выпадающее меню — сначала предметы из расписания дня, затем все остальные.
class SubjectPicker extends StatelessWidget {
  const SubjectPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.suggested = const [],
    this.label = 'Предмет',
  });
  final String selected;
  final ValueChanged<String> onSelect;
  final List<String> suggested;
  final String label;

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

    return SelectField<String>(
      label: label,
      icon: Icons.menu_book_rounded,
      value: selected.isEmpty ? null : selected,
      valueLabel: selected.isEmpty ? null : store.subjectName(selected),
      placeholder: 'Выберите предмет',
      options: [
        for (final s in first) MenuOption(s, store.subjectName(s), icon: Icons.event_note_rounded, section: 'По расписанию'),
        for (final s in rest)
          MenuOption(s, store.subjectName(s), icon: Icons.menu_book_outlined, section: first.isEmpty ? null : 'Все предметы'),
      ],
      onSelected: onSelect,
      actions: [
        MenuAction(
          icon: Icons.add_rounded,
          label: 'Новый предмет…',
          onTap: () async {
            final v = await promptText(context, title: 'Новый предмет', hint: 'Название');
            if (v == null || v.trim().isEmpty) return;
            store.addExtraSubject(v.trim());
            onSelect(v.trim());
          },
        ),
      ],
    );
  }
}

/// Выбор типа работы выпадающим меню.
class KindPicker extends StatelessWidget {
  const KindPicker({super.key, required this.kind, required this.kinds, required this.onChanged});
  final String kind;
  final List<String> kinds;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final list = [...kinds];
    if (kind.isNotEmpty && !list.contains(kind)) list.insert(0, kind);
    return SelectField<String>(
      label: 'Тип работы',
      icon: Icons.assignment_rounded,
      value: kind.isEmpty ? '' : kind,
      valueLabel: kind,
      placeholder: 'Не указан',
      options: [
        const MenuOption('', 'Не указан', icon: Icons.remove_circle_outline_rounded),
        for (final k in list) MenuOption(k, k, icon: Icons.assignment_outlined),
      ],
      onSelected: onChanged,
    );
  }
}

// ───────────────────────── кнопки-«квадраты» ─────────────────────────

/// Круглая/квадратная кнопка с цифрой (оценка, номер пары): выбранная превращается из «квадрата» в круг.
class ChoiceSquare extends StatelessWidget {
  const ChoiceSquare({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tone,
    required this.accent,
    this.size = 52,
    this.marked = false,
    this.semantics,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Tone tone;
  final Color accent;
  final double size;
  final bool marked;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final onAccent = onColorFor(accent);
    return Semantics(
      button: true,
      selected: selected,
      label: semantics ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : tone.bg,
                borderRadius: BorderRadius.circular(selected ? size / 2 : size * 0.3),
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: selected ? onAccent : tone.fg),
                child: Text(label),
              ),
            ),
            if (marked)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.cs.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.cs.surfaceContainerLow, width: 2),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Клавиатура оценок 1–10: две строки по пять, цвет каждой кнопки соответствует оценке.
class GradePad extends StatelessWidget {
  const GradePad({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final size = ((c.maxWidth - gap * 4) / 5).clamp(44.0, 68.0).toDouble();
      Widget row(int from) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var v = from; v < from + 5; v++)
                ChoiceSquare(
                  label: '$v',
                  semantics: 'Оценка $v',
                  size: size,
                  selected: value == v,
                  tone: gradeTone(context, v),
                  accent: gradeAccent(context, v),
                  onTap: () => onChanged(v),
                ),
            ],
          );
      return Column(children: [row(1), const SizedBox(height: gap), row(6)]);
    });
  }
}

// ───────────────────────── причина пропуска ─────────────────────────

/// Большая плитка «без уважительной» / «по уважительной».
/// В быстрой шторке нажатие сразу сохраняет; в форме правки плитка показывает выбранное состояние.
class ExcuseTile extends StatelessWidget {
  const ExcuseTile({super.key, required this.excused, required this.onTap, this.selected = false, this.enabled = true});
  final bool excused;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tone = absenceTone(context, excused: excused);
    final title = excused ? 'По уважительной' : 'Без уважительной';
    final sub = excused ? 'Справка, болезнь' : 'Обычный пропуск';
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: tone.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: selected ? tone.fg : Colors.transparent, width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  Haptics.selection();
                  onTap();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tone.fg.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(excused ? Icons.verified_rounded : Icons.event_busy_rounded, size: 22, color: tone.fg),
                ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle_rounded, color: tone.fg),
              ]),
              const SizedBox(height: 12),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall?.copyWith(color: tone.fg.withValues(alpha: 0.8))),
            ]),
          ),
        ),
      ),
    );
  }
}
