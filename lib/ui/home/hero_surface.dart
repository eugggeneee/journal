import 'package:material_ui/material_ui.dart';

import '../kit/foundation/ctx.dart';

/// Верх главной: цветная поверхность во всю ширину с закруглением снизу. Шапка (приветствие, настройки)
/// стоит прямо на ней, поэтому экран читается как один цельный блок, а не набор карточек.
class HeroSurface extends StatelessWidget {
  const HeroSurface({super.key, required this.tone, required this.child, this.header});
  final Tone tone;
  final Widget child;

  /// Шапка на поверхности; получает цвет текста, подходящий к фону.
  final Widget Function(Color fg)? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!(tone.fg), const SizedBox(height: 16)],
          child,
        ],
      ),
    );
  }
}
