import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';

/// Строка-сводка дня: сколько пар, во сколько начало и конец, сколько пропущено,
/// и кнопка «Весь день» с меню дополнительных действий (Split button Material 3).
class DaySummary extends StatelessWidget {
  const DaySummary({
    super.key,
    required this.pairs,
    required this.hours,
    required this.subtitle,
    required this.allMarked,
    required this.shortDay,
    required this.onWholeDay,
    required this.onShortDay,
    required this.onMark,
  });
  final int pairs;
  final int hours;
  final String subtitle;
  final bool allMarked;
  final bool shortDay;
  final VoidCallback onWholeDay;
  final VoidCallback onShortDay;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pairsText(pairs), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            // Высота строки постоянна: плашка с часами появляется на её месте и ничего не сдвигает.
            SizedBox(
              height: 26,
              child: Row(children: [
                AnimatedSize(
                  duration: context.motion(Motion.short),
                  curve: Motion.standard,
                  alignment: Alignment.centerLeft,
                  child: PopIn(
                    token: hours,
                    child: hours > 0
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pill(hoursText(hours), tone: absenceTone(context, excused: false), icon: Icons.event_busy_rounded),
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        _WholeDaySplit(
          allMarked: allMarked,
          shortDay: shortDay,
          onWholeDay: onWholeDay,
          onShortDay: onShortDay,
          onMark: onMark,
        ),
      ]),
    );
  }
}

/// Split button: слева основное действие, справа стрелка с меню. Половинки разделены зазором 2 dp
/// и скруглены сильнее с внешней стороны, как в спецификации Material 3 Expressive.
class _WholeDaySplit extends StatelessWidget {
  const _WholeDaySplit({
    required this.allMarked,
    required this.shortDay,
    required this.onWholeDay,
    required this.onShortDay,
    required this.onMark,
  });
  final bool allMarked;
  final bool shortDay;
  final VoidCallback onWholeDay;
  final VoidCallback onShortDay;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    const outer = Radius.circular(22);
    const inner = Radius.circular(6);
    final d = context.motion(Motion.short);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: outer, right: inner)),
        ),
        icon: AnimatedSwitcher(
          duration: d,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: Icon(allMarked ? Icons.event_available_rounded : Icons.event_busy_rounded, key: ValueKey(allMarked), size: 20),
        ),
        label: Swap(
          alignment: Alignment.center,
          child: Text(allMarked ? 'Снять день' : 'Весь день', key: ValueKey(allMarked)),
        ),
        onPressed: onWholeDay,
      ),
      const SizedBox(width: 2),
      MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.timelapse_rounded),
            trailingIcon: shortDay ? Icon(Icons.check_rounded, color: cs.primary) : null,
            onPressed: onShortDay,
            child: const Text('Сокращённый день'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.bookmark_add_outlined),
            onPressed: onMark,
            child: const Text('Пометка на день'),
          ),
        ],
        builder: (context, controller, _) => FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: inner, right: outer)),
          ),
          onPressed: () {
            Haptics.selection();
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Semantics(
            label: 'Ещё действия дня',
            child: AnimatedRotation(
              turns: controller.isOpen ? 0.5 : 0,
              duration: d,
              curve: Motion.standard,
              child: const Icon(Icons.arrow_drop_down_rounded, size: 28),
            ),
          ),
        ),
      ),
    ]);
  }
}
