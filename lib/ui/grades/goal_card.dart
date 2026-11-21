import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/store.dart';
import '../../logic/forecast.dart';
import '../kit/animation/motion.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/journal_theme.dart';
import '../kit/sheets/select_sheet.dart';

/// Цель по предмету: свой целевой средний балл, полоса прогресса к нему и прогноз
/// «сколько нужно получить, чтобы дотянуть». Нажатие меняет цель.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.subject, required this.values, required this.store});
  final String subject;
  final List<int> values;
  final AppStore store;

  void _pick(BuildContext context) {
    final goal = store.settings.goals[subject];
    Haptics.selection();
    showSelectSheet<int>(
      context,
      title: 'Цель по предмету',
      subtitle: 'Какого среднего балла вы хотите добиться',
      value: goal,
      options: [for (var g = 10; g >= 4; g--) MenuOption(g, 'Средний балл $g', icon: Icons.flag_rounded)],
      actions: [
        if (goal != null)
          MenuAction(icon: Icons.flag_outlined, label: 'Снять цель', onTap: () => store.setGoal(subject, null)),
      ],
      onSelected: (v) => store.setGoal(subject, v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final goal = store.settings.goals[subject];
    final avg = values.isEmpty ? null : values.fold<int>(0, (a, v) => a + v) / values.length;
    final f = goal == null ? Forecast.none : Forecast.to(values, goal);
    final accent = f.reached ? hueAccent(context, kHueGreen) : hueAccent(context, kHueAmber);

    return SegmentCard(
      index: 0,
      count: 1,
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconBox(icon: Icons.flag_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Цель по предмету', style: tt.titleMedium?.copyWith(fontWeight: JournalType.emphasis, height: 1.2)),
                Text(
                  goal == null ? 'Не задана: нажмите, чтобы выбрать' : 'Средний балл $goal',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
          ]),
          if (goal != null && avg != null) ...[
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(fmtAvg(avg), style: tt.headlineSmall?.copyWith(fontWeight: JournalType.heading)),
              Text(' из $goal', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: (avg / goal).clamp(0.0, 1.0).toDouble()),
              duration: context.motion(Motion.long),
              curve: Motion.standard,
              builder: (context, v, _) => Bar(value: v, color: accent, height: 10, track: accent.withValues(alpha: 0.18)),
            ),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(f.reached ? Icons.check_circle_rounded : Icons.trending_up_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(forecastText(f, goal), style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3))),
            ]),
          ],
        ]),
      ),
    );
  }
}
