import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/sheet.dart';

/// Открывает нижнюю шторку выбора группы (из профиля и меню расписания).
Future<void> openGroupPicker(BuildContext context) {
  final store = StoreScope.of(context);
  final repo = StoreScope.repoOf(context);
  return showGroupSheet(
    context,
    selected: store.settings.group,
    onSelected: (g) {
      store.setGroup(g);
      repo.prefetch(respectSetting: false);
    },
  );
}

/// Шторка выбора группы: поиск, сетка групп с сайта колледжа и ввод номера вручную.
/// На планшете и ПК показывается диалогом по центру.
Future<void> showGroupSheet(
  BuildContext context, {
  required String selected,
  required ValueChanged<String> onSelected,
}) =>
    showAdaptiveSheet<void>(
      context,
      (ctx) => GroupSheet(
        selected: selected,
        onSelected: (g) {
          Navigator.of(ctx).pop();
          onSelected(g);
        },
      ),
    );

class GroupSheet extends StatefulWidget {
  const GroupSheet({super.key, required this.onSelected, this.selected = ''});
  final ValueChanged<String> onSelected;
  final String selected;
  @override
  State<GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<GroupSheet> {
  final TextEditingController _q = TextEditingController();
  List<String> _groups = const [];
  bool _loading = true;
  bool _offline = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = StoreScope.repoOf(context);
    setState(() => _loading = true);
    final r = await repo.service.listGroups();
    if (!mounted) return;
    setState(() {
      _groups = r.groups;
      _offline = r.offline;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final query = _q.text.trim();
    final filtered = _groups.where((g) => g.contains(query)).toList();
    final manualOk = RegExp(r'^\d{3,5}$').hasMatch(query) && !_groups.contains(query);

    final Widget body;
    final String stateKey;
    if (_loading) {
      stateKey = 'loading';
      body = const Padding(padding: EdgeInsets.symmetric(vertical: 56), child: Center(child: CircularProgressIndicator()));
    } else if (_offline) {
      stateKey = 'offline';
      body = _Notice(
        icon: Icons.wifi_off_rounded,
        text: 'Нет подключения. Подключитесь к интернету, чтобы увидеть список групп, или введите номер вручную.',
        onRetry: _load,
      );
    } else if (_groups.isEmpty) {
      stateKey = 'empty';
      body = _Notice(
        icon: Icons.error_outline_rounded,
        text: 'Список групп сейчас недоступен — расписание на сайте не опубликовано. Введите номер вручную.',
        onRetry: _load,
      );
    } else if (filtered.isEmpty) {
      stateKey = 'nomatch';
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            manualOk ? 'Такой группы нет в списке — можно ввести номер вручную' : 'Такой группы нет в списке',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    } else {
      stateKey = 'grid';
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
          child: Text(
            query.isEmpty ? 'Группы на сайте · ${_groups.length}' : 'Найдено: ${filtered.length}',
            style: context.tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
          ),
        ),
        _GroupGrid(groups: filtered, selected: widget.selected, onTap: widget.onSelected),
      ]);
    }

    return SheetHeight(
      child: SheetScaffold(
        title: 'Выбор группы',
        subtitle: widget.selected.isEmpty ? 'Выберите из списка или введите номер' : 'Сейчас: ${widget.selected}',
        fill: true,
        pinned: TextField(
          controller: _q,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Номер группы',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_q.clear),
                  ),
          ),
        ),
        footer: manualOk
            ? FilledButton(
                onPressed: () {
                  Haptics.selection();
                  widget.onSelected(query);
                },
                child: Text('Использовать группу $query'),
              )
            : null,
        children: [Smooth(child: KeyedSubtree(key: ValueKey(stateKey), child: body))],
      ),
    );
  }
}

/// Сетка групп: плитки одинакового размера, число столбцов подстраивается под ширину — ничего не обрезается.
class _GroupGrid extends StatelessWidget {
  const _GroupGrid({required this.groups, required this.selected, required this.onTap});
  final List<String> groups;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final cols = ((c.maxWidth + gap) / (92 + gap)).floor().clamp(3, 6);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final g in groups)
            SizedBox(
              width: w,
              child: _GroupTile(label: g, selected: g == selected, onTap: () => onTap(g)),
            ),
        ]);
      });
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    void tap() {
      Haptics.selection();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: 'Группа $label',
      onTap: tap,
      excludeSemantics: true,
      child: Material(
        animationDuration: context.motion(Motion.short),
        color: selected ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(selected ? 26 : 16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: context.motion(Motion.short),
                curve: Motion.standard,
                maxLines: 1,
                style: (context.tt.titleMedium ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? cs.onPrimary : cs.onSurface,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: context.cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: context.tt.bodyMedium?.copyWith(height: 1.4, color: context.cs.onSurfaceVariant))),
          ]),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Повторить')),
        ]),
      );
}
