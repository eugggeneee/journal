import 'package:material_ui/material_ui.dart';

import '../../../core/haptics.dart';
import '../foundation/ctx.dart';
import 'sheet.dart';

/// Пункт списка выбора. [section] — подпись группы (появляется, когда меняется от пункта к пункту).
class MenuOption<T> {
  const MenuOption(this.value, this.label, {this.icon, this.section});
  final T value;
  final String label;
  final IconData? icon;
  final String? section;
}

/// Действие в конце списка (например, «Новый предмет…»).
class MenuAction {
  const MenuAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Крупная строка выбора Material 3: выбранная подсвечивается и получает галочку.
/// Длинный текст переносится, а не обрезается.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.card = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Невыбранная строка с лёгкой заливкой (для списков внутри форм).
  final bool card;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = selected ? cs.onSecondaryContainer : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? cs.secondaryContainer : (card ? cs.surfaceContainerHighest.withValues(alpha: 0.6) : Colors.transparent),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Haptics.selection();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22, color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodyLarge?.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: fg),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(Icons.check_rounded, size: 22, color: cs.onSecondaryContainer),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Список вариантов в форме: каждый вариант — своя строка во всю ширину (подходит для 2–4 вариантов).
class ChoiceList<T> extends StatelessWidget {
  const ChoiceList({super.key, required this.options, required this.value, required this.onChanged});
  final List<MenuOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final o in options)
          OptionTile(
            label: o.label,
            icon: o.icon,
            card: true,
            selected: value != null && o.value == value,
            onTap: () => onChanged(o.value),
          ),
      ]);
}

/// Нижняя шторка выбора: нажали на поле — снизу открылся список со всеми вариантами.
/// Если вариантов много, сверху появляется поиск. На планшете и ПК показывается диалогом.
Future<void> showSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<MenuOption<T>> options,
  required ValueChanged<T> onSelected,
  T? value,
  String? subtitle,
  List<MenuAction> actions = const [],
}) =>
    showAdaptiveSheet<void>(
      context,
      (ctx) => _SelectSheet<T>(
        title: title,
        subtitle: subtitle,
        options: options,
        value: value,
        actions: actions,
        onSelected: (v) {
          Navigator.of(ctx).pop();
          onSelected(v);
        },
        onAction: (a) {
          Navigator.of(ctx).pop();
          a.onTap();
        },
      ),
    );

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.value,
    required this.actions,
    required this.onSelected,
    required this.onAction,
  });
  final String title;
  final String? subtitle;
  final List<MenuOption<T>> options;
  final T? value;
  final List<MenuAction> actions;
  final ValueChanged<T> onSelected;
  final ValueChanged<MenuAction> onAction;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  static const _searchFrom = 8;
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final searchable = widget.options.length > _searchFrom;
    final query = _q.text.trim().toLowerCase();
    final visible = query.isEmpty ? widget.options : widget.options.where((o) => o.label.toLowerCase().contains(query)).toList();

    final children = <Widget>[];
    String? lastSection;
    for (final o in visible) {
      if (o.section != null && o.section != lastSection) {
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(8, children.isEmpty ? 4 : 16, 8, 6),
          child: Text(o.section!, style: context.tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ));
      }
      lastSection = o.section;
      children.add(OptionTile(
        label: o.label,
        icon: o.icon,
        selected: widget.value != null && o.value == widget.value,
        onTap: () => widget.onSelected(o.value),
      ));
    }
    if (visible.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text('Ничего не найдено', style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
      ));
    }
    if (widget.actions.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Divider(height: 1, color: cs.outlineVariant),
      ));
      for (final a in widget.actions) {
        children.add(OptionTile(
          label: a.label,
          icon: a.icon,
          selected: false,
          onTap: () => widget.onAction(a),
        ));
      }
    }

    final sheet = SheetScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      fill: searchable,
      pinned: searchable
          ? TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Поиск',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_q.clear),
                      ),
              ),
            )
          : null,
      children: children,
    );
    return searchable ? SheetHeight(child: sheet) : sheet;
  }
}
