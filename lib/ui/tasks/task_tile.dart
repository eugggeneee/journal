import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../kit/animation/motion.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'task_sheet.dart';

/// Срок задания словами: «Сегодня», «Завтра», день недели, дата или «Просрочено на 2 дня».
String dueText(DateTime due) {
  final d = dayDiff(due, today());
  if (d < 0) return 'Просрочено на ${daysText(-d)}';
  if (d == 0) return 'Сегодня';
  if (d == 1) return 'Завтра';
  return d < 7 ? weekdayName(due) : shortDate(due);
}

/// Цвет срока: просроченное красным, сегодняшнее янтарным, остальное спокойно.
Tone dueTone(BuildContext context, Task t) {
  final cs = context.cs;
  if (t.done) return Tone(cs.surfaceContainerHighest, cs.onSurfaceVariant);
  final d = dayDiff(t.due, today());
  if (d < 0) return hueTone(context, 4);
  if (d == 0) return hueTone(context, kHueAmber);
  return Tone(cs.secondaryContainer, cs.onSecondaryContainer);
}

/// Круглая отметка «сделано»: нажатие переключает, сама зона нажатия 48 на 48.
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.task, required this.store});
  final Task task;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final done = task.done;
    void toggle() {
      Haptics.selection();
      store.toggleTask(task.id);
      showUndo(
        ScaffoldMessenger.of(context),
        done ? 'Задание снова открыто' : 'Задание выполнено',
        () => store.saveTask(task),
      );
    }

    return Semantics(
      container: true,
      button: true,
      onTap: toggle,
      checked: done,
      label: done ? 'Вернуть в невыполненные' : 'Отметить выполненным',
      excludeSemantics: true,
      child: InkResponse(
        onTap: toggle,
        radius: 28,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(Motion.short),
              curve: Motion.standard,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? cs.primary : Colors.transparent,
                border: Border.all(color: done ? cs.primary : cs.outline, width: 2),
              ),
              child: AnimatedScale(
                scale: done ? 1 : 0,
                duration: context.motion(Motion.short),
                curve: Motion.spring,
                child: Icon(Icons.check_rounded, size: 18, color: cs.onPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка задания: отметка слева, текст целиком, под ним вид, предмет и срок. Смахивание влево удаляет с отменой.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.store, required this.index, required this.count});
  final Task task;
  final AppStore store;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = task;
    return SegmentCard(
      index: index,
      count: count,
      dismissKey: ValueKey('task-${t.id}'),
      onDelete: () {
        final messenger = ScaffoldMessenger.of(context);
        store.deleteTask(t.id);
        Haptics.medium();
        showUndo(messenger, 'Задание удалено', () => store.saveTask(t));
      },
      onTap: () => showTaskSheet(context, edit: t),
      child: TaskSummary(task: t, store: store, showKind: true),
    );
  }
}

/// Содержимое задания на главной, в журнале и в расписании.
class TaskSummary extends StatelessWidget {
  const TaskSummary({super.key, required this.task, required this.store, this.showKind = false});
  final Task task;
  final AppStore store;
  final bool showKind;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskCheck(task: task, store: store),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.text,
                    style: context.tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: task.done ? cs.onSurfaceVariant : cs.onSurface,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(dueText(task.due), tone: dueTone(context, task), icon: Icons.event_rounded),
                      if (showKind) Text(task.homework ? 'Домашнее задание' : 'Заметка', style: context.tt.labelMedium),
                      if (task.subject.isNotEmpty)
                        Text(
                          store.subjectName(task.subject),
                          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
