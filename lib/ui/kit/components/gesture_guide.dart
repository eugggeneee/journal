import 'package:material_ui/material_ui.dart';

import '../foundation/ctx.dart';
import 'widgets.dart';

/// Руководство по жестам: шесть коротких карточек. Используется на стартовых экранах и в «Поведении».
class GestureGuide extends StatelessWidget {
  const GestureGuide({super.key, this.compact = false});

  /// Плотный вид для стартовых экранов: всё помещается на экран без прокрутки.
  final bool compact;

  static const _items = [
    (Icons.touch_app_rounded, 'Нажмите на пару', 'Откроются подробности: пропуск, оценка и пометка.'),
    (Icons.pan_tool_alt_rounded, 'Коротко удержите пару', 'Пропуск отметится или снимется без лишних шагов.'),
    (Icons.swipe_rounded, 'Листайте день', 'Проведите по расписанию влево или вправо, чтобы открыть соседний день.'),
    (Icons.swipe_left_rounded, 'Смахните запись влево', 'Оценка, пропуск или пометка удалится. Действие можно отменить в сообщении внизу.'),
    (Icons.south_rounded, 'Потяните список вниз', 'Расписание обновится с сайта колледжа.'),
    (Icons.unfold_less_rounded, 'Сверните карточку дня', 'Кнопка в углу карточки превращает её в тонкую полоску состояния.'),
  ];

  @override
  Widget build(BuildContext context) {
    final tones = [for (final h in const [kHueBlue, kHueViolet, kHueRose, kHueAmber, kHueGreen, kHueTeal]) hueTone(context, h)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < _items.length; i++)
        SegmentCard(
          index: i,
          count: _items.length,
          child: _GestureRow(icon: _items[i].$1, tone: tones[i % tones.length], title: _items[i].$2, text: _items[i].$3, compact: compact),
        ),
    ]);
  }
}

class _GestureRow extends StatelessWidget {
  const _GestureRow({required this.icon, required this.tone, required this.title, required this.text, required this.compact});
  final IconData icon;
  final Tone tone;
  final String title;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final box = compact ? 40.0 : 46.0;
    return Padding(
        padding: EdgeInsets.fromLTRB(14, compact ? 9 : 14, 14, compact ? 9 : 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: box,
            height: box,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(box * 0.34)),
            child: Icon(icon, size: compact ? 22 : 24, color: tone.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: (compact ? context.tt.titleSmall : context.tt.titleMedium)?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(text, style: (compact ? context.tt.bodySmall : context.tt.bodyMedium)?.copyWith(color: context.cs.onSurfaceVariant, height: 1.25)),
            ]),
          ),
        ]),
      );
  }
}
