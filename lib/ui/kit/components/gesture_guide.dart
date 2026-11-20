import 'package:material_ui/material_ui.dart';

import 'widgets.dart';

/// Руководство по жестам: шесть коротких карточек. Используется на стартовых экранах и в «Поведении».
class GestureGuide extends StatelessWidget {
  const GestureGuide({super.key});

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
  Widget build(BuildContext context) => GuideRows(_items);
}

class GuideRows extends StatelessWidget {
  const GuideRows(this.items, {super.key});
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++)
        SegmentCard(index: i, count: items.length,
          child: JournalRow(leading: IconBox(icon: items[i].$1),
            title: items[i].$2, subtitle: items[i].$3)),
    ],
  );
}
