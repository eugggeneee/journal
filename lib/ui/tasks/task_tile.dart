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
  const TaskCheck({super.key, required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Вернуть в невыполненные' : 'Отметить выполненным',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
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
    final cs = context.cs;
    final tt = context.tt;
    final t = task;
    final due = dueTone(context, t);
    final kind = t.homework ? Tone(cs.primaryContainer, cs.onPrimaryContainer) : Tone(cs.tertiaryContainer, cs.onTertiaryContainer);
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TaskCheck(
            done: t.done,
            onTap: () {
              Haptics.selection();
              store.toggleTask(t.id);
            },
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedDefaultTextStyle(
                  duration: context.motion(Motion.short),
                  style: (tt.titleMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    decoration: t.done ? TextDecoration.lineThrough : TextDecoration.none,
                    color: t.done ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                  child: Text(t.text),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Pill(t.homework ? 'Домашнее задание' : 'Заметка', tone: kind, icon: t.homework ? Icons.menu_book_rounded : Icons.sticky_note_2_rounded),
                  if (t.subject.isNotEmpty) Text(store.subjectName(t.subject), style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  Pill(dueText(t.due), tone: due, icon: Icons.event_rounded),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
