import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/journal_theme.dart';
import 'task_sheet.dart';
import 'task_tile.dart';

/// Задания: домашняя работа и заметки со сроком, сгруппированные по срочности.
/// Просроченное сверху, выполненное внизу. Отметка слева, смахивание влево удаляет с отменой.
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final t = today();
    final open = store.openTasks;
    final overdue = [for (final x in open) if (x.due.isBefore(t)) x];
    final todayList = [for (final x in open) if (sameDay(x.due, t)) x];
    final tomorrow = [for (final x in open) if (sameDay(x.due, addDays(t, 1))) x];
    final later = [for (final x in open) if (x.due.isAfter(addDays(t, 1))) x];
    final done = [for (final x in store.tasks) if (x.done) x]..sort((a, b) => b.due.compareTo(a.due));

    Widget group(String title, List<Task> list, {String? trailing}) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(title, trailing: trailing ?? '${list.length}'),
        for (var i = 0; i < list.length; i++) TaskTile(key: ValueKey('t-${list[i].id}'), task: list[i], store: store, index: i, count: list.length),
      ]);
    }

    final empty = store.tasks.isEmpty;
    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Haptics.selection();
          showTaskSheet(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Задание'),
      ),
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SubHeader('Задания', subtitle: open.isEmpty ? 'Всё сделано' : '${open.length} ${plural(open.length, 'невыполненное', 'невыполненных', 'невыполненных')}'),
            if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Заданий нет',
                  message: 'Записывайте домашнее задание и заметки к парам: срок напомнит о себе на главной.',
                  action: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить задание'),
                    onPressed: () => showTaskSheet(context),
                  ),
                ),
              )
            else
              Inset(children: [
                Appear(child: group('Просрочено', overdue)),
                Appear(index: 1, child: group('Сегодня', todayList)),
                Appear(index: 2, child: group('Завтра', tomorrow)),
                Appear(index: 3, child: group('Позже', later)),
                Appear(index: 4, child: group('Выполнено', done)),
              ]),
            const SliverToBoxAdapter(child: SizedBox(height: kFabClearance)),
          ],
        ),
      ),
    );
  }
}
