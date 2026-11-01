import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import 'kit/ctx.dart';
import 'kit/pickers.dart';
import 'kit/widgets.dart';
import 'scope.dart';

/// Открывает выбор группы отдельной страницей (из профиля и меню расписания).
Future<void> openGroupPicker(BuildContext context) {
  final store = StoreScope.of(context);
  final repo = StoreScope.repoOf(context);
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(
    builder: (ctx) => GroupPickerScreen(
      onSelected: (g) {
        store.setGroup(g);
        repo.prefetch(respectSetting: false);
        Navigator.of(ctx).pop();
      },
    ),
  ));
}

class GroupPickerScreen extends StatelessWidget {
  const GroupPickerScreen({super.key, required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Выбор группы')),
        body: ContentFrame(
          maxWidth: 640,
          child: GroupPickerBody(
            selected: StoreScope.of(context).settings.group,
            onSelected: onSelected,
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 32),
          ),
        ),
      );
}

/// Поиск + список групп с сайта колледжа. Общий для приветствия и отдельной страницы.
class GroupPickerBody extends StatefulWidget {
  const GroupPickerBody({super.key, required this.onSelected, this.selected = '', this.padding = const EdgeInsets.all(16)});
  final ValueChanged<String> onSelected;
  final String selected;
  final EdgeInsets padding;
  @override
  State<GroupPickerBody> createState() => _GroupPickerBodyState();
}

class _GroupPickerBodyState extends State<GroupPickerBody> {
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

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: widget.padding,
      children: [
        TextField(
          controller: _q,
          keyboardType: TextInputType.number,
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
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 56), child: Center(child: CircularProgressIndicator()))
        else ...[
          if (_offline)
            _Notice(
              icon: Icons.wifi_off_rounded,
              text: 'Нет подключения. Подключитесь к интернету, чтобы увидеть список групп, или введите номер вручную.',
              onRetry: _load,
            )
          else if (_groups.isEmpty)
            _Notice(
              icon: Icons.error_outline_rounded,
              text: 'Список групп сейчас недоступен — расписание на сайте не опубликовано. Введите номер вручную.',
              onRetry: _load,
            )
          else ...[
            const SectionHeader('Группы на сайте', top: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Такой группы нет в списке', style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in filtered)
                  ChoiceTag(
                    label: g,
                    selected: g == widget.selected,
                    onTap: () => widget.onSelected(g),
                  ),
              ]),
          ],
          if (manualOk) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Haptics.selection();
                widget.onSelected(query);
              },
              child: Text('Использовать группу $query'),
            ),
          ],
        ],
      ],
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
