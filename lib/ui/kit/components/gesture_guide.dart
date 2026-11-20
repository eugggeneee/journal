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
    (
      Icons.swipe_left_rounded,
      'Смахните запись влево',
      'Оценка, пропуск или пометка удалится. Действие можно отменить в сообщении внизу.',
    ),
    (Icons.south_rounded, 'Потяните список вниз', 'Расписание обновится с сайта колледжа.'),
    (
      Icons.unfold_less_rounded,
      'Сверните карточку дня',
      'Кнопка в углу карточки превращает её в тонкую полоску состояния.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tones = [
      for (final h in const [kHueBlue, kHueViolet, kHueRose, kHueAmber, kHueGreen, kHueTeal]) hueTone(context, h),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _items.length; i++)
          SegmentCard(
            index: i,
            count: _items.length,
            child: JournalRow(
              leading: IconBox(icon: _items[i].$1, tone: tones[i], size: compact ? 40 : 46),
              compact: compact,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 12),
              title: _items[i].$2,
              subtitle: _items[i].$3,
            ),
          ),
      ],
    );
  }
}
