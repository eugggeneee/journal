import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../data/models.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/settings_tiles.dart';

/// Главная: какие блоки показывать и в каком порядке. Переключатель скрывает блок, стрелки двигают его
/// выше или ниже. Цветной блок дня всегда остаётся сверху.
class HomeLayoutPage extends StatelessWidget {
  const HomeLayoutPage({super.key});

  static const _info = {
    kBlockMetrics: (Icons.insights_rounded, 'Показатели', 'Балл, пропуски и задания в карточке дня', kHueBlue),
    kBlockTasks: (Icons.task_alt_rounded, 'Задания', 'Домашнее задание и заметки со сроком', kHueTeal),
    kBlockTomorrow: (Icons.event_rounded, 'Завтра', 'Сколько пар и когда начало', kHueViolet),
    kBlockWeek: (Icons.view_week_rounded, 'Эта неделя', 'Число пар по дням', kHueGreen),
    kBlockRecent: (Icons.star_rounded, 'Последние оценки', 'Три последние записи', kHueAmber),
  };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final tt = context.tt;
    final order = [kBlockMetrics, ...store.settings.homeOrder.where((id) => id != kBlockMetrics)];
    final hidden = store.settings.homeHidden;

    void move(int i, int delta) {
      final j = i + delta;
      if (i == 0 || j < 1 || j >= order.length) return;
      Haptics.selection();
      final next = [...order];
      final item = next.removeAt(i);
      next.insert(j, item);
      store.setHomeLayout(next, hidden);
    }

    void toggle(String id, bool visible) {
      Haptics.selection();
      final next = [...hidden]..remove(id);
      if (!visible) next.add(id);
      store.setHomeLayout(order, next);
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            const SubHeader('Главная', subtitle: 'Блоки и их порядок'),
            Inset(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Выключите ненужное или передвиньте блок стрелками. Цветной блок дня остаётся сверху всегда.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                ),
              ),
              for (var i = 0; i < order.length; i++)
                SegmentCard(
                  key: ValueKey('layout-${order[i]}'),
                  index: i,
                  count: order.length,
                  appear: false,
                  child: Builder(builder: (context) {
                    final id = order[i];
                    final info = _info[id]!;
                    final visible = !hidden.contains(id);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                      child: Row(children: [
                        AnimatedOpacity(
                          opacity: visible ? 1 : 0.5,
                          duration: Motion.short,
                          child: IconBox(icon: info.$1, tone: hueTone(context, info.$4)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(info.$2, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                            Text(info.$3, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          ]),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          SettingsSwitch(value: visible, onChanged: (v) => toggle(id, v)),
                        ]),
                        if (id != kBlockMetrics) Column(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Выше',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                            onPressed: i == 1 ? null : () => move(i, -1),
                          ),
                          IconButton(
                            tooltip: 'Ниже',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            onPressed: i == order.length - 1 ? null : () => move(i, 1),
                          ),
                        ]),
                      ]),
                    );
                  }),
                ),
              const SizedBox(height: 16),
              SegmentCard(
                index: 0,
                count: 1,
                onTap: () {
                  Haptics.selection();
                  store.setHomeLayout(kHomeBlocks, const []);
                },
                child: const SettingsTile(icon: Icons.restart_alt_rounded, title: 'Вернуть обычный вид', subtitle: 'Все блоки в первоначальном порядке'),
              ),
              SegmentCard(
                index: 0,
                count: 1,
                onTap: () {
                  Haptics.selection();
                  store.setTipGestures(false);
                },
                child: const SettingsTile(icon: Icons.lightbulb_outline_rounded, title: 'Показать подсказку о жестах', subtitle: 'Снова вывести подсказку на главной'),
              ),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
