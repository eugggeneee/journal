import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/store.dart';
import '../../logic/limits.dart';
import '../../logic/stats.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../tasks/tasks_page.dart';

class DayMetrics extends StatelessWidget {
  const DayMetrics({super.key, required this.store, required this.onTab, required this.tone, required this.compact});
  final Tone tone;
  final bool compact;
  final AppStore store;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final avg = GradeStats.of(store.grades).average;
    final hours = monthUnexcusedHours(store.absences, today());
    final open = store.openTasks;
    final tomorrow = open.where((t) => sameDay(t.due, addDays(today(), 1))).length;
    final items = <(String, String, String, VoidCallback)>[
      ('Средний балл', avg == null ? '—' : fmtAvg(avg), gradesText(store.grades.length), () => onTab(2)),
      ('Пропуски', '$hours ч', 'из $kMonthLimit ч', () => onTab(3)),
      (
        'Задания',
        '${open.length}',
        tomorrow == 0 ? 'к сдаче' : 'завтра $tomorrow',
        () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TasksPage()));
        },
      ),
    ];
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: GroupTile(
              index: i,
              count: items.length,
              color: tone.fg.withValues(alpha: .12),
              onTap: items[i].$4,
              child: Semantics(
                label: '${items[i].$1}, ${items[i].$2}, ${items[i].$3}',
                excludeSemantics: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 4 : 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            compact && i == 0 ? 'Балл' : items[i].$1,
                            style: context.tt.labelMedium?.copyWith(color: tone.fg),
                          ),
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].$2,
                            style: (compact ? context.tt.titleLarge : context.tt.headlineSmall)?.copyWith(
                              color: tone.fg,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (!compact) Text(items[i].$3, style: context.tt.labelSmall?.copyWith(color: tone.fg)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
    if (compact) return SizedBox(height: MediaQuery.textScalerOf(context).scale(32).clamp(52.0, 76.0), child: row);
    return IntrinsicHeight(child: row);
  }
}
