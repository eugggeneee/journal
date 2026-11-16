import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/foundation/ctx.dart';

/// Split button: слева основное действие, справа стрелка с меню. Половинки разделены зазором 2 dp
/// и скруглены сильнее с внешней стороны. Цвета берутся у карточки, на которой кнопка стоит.
class WholeDaySplit extends StatelessWidget {
  const WholeDaySplit({
    required this.fg,
    required this.allMarked,
    required this.shortDay,
    required this.enabled,
    required this.onWholeDay,
    required this.onShortDay,
    required this.onMark,
  });
  final Color fg;
  final bool allMarked;
  final bool shortDay;
  final bool enabled;
  final VoidCallback onWholeDay;
  final VoidCallback onShortDay;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    const outer = Radius.circular(24);
    const inner = Radius.circular(6);
    final d = context.motion(Motion.short);
    final bg = fg.withValues(alpha: 0.14);
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: outer, right: inner)),
        ),
        icon: AnimatedSwitcher(
          duration: d,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: Icon(allMarked ? Icons.event_available_rounded : Icons.event_busy_rounded, key: ValueKey(allMarked), size: 20),
        ),
        // Ширина кнопки меняется вместе с подписью плавно, а не рывком.
        label: AnimatedSize(
          duration: d,
          curve: Motion.standard,
          child: Swap(
            alignment: Alignment.center,
            child: Text(allMarked ? 'Снять день' : 'Весь день', key: ValueKey(allMarked)),
          ),
        ),
        onPressed: enabled
            ? () {
                Haptics.selection();
                onWholeDay();
              }
            : null,
        ),
      ),
      const SizedBox(width: 2),
      MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
          ),
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
        builder: (context, controller, _) => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            minimumSize: const Size(48, 48),
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
