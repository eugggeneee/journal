import 'package:flutter/services.dart' show SystemUiOverlayStyle;
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayForSurface(tone.bg),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 4, 20, 16),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[header!(tone.fg), const SizedBox(height: 8)],
            child,
          ],
        ),
      ),
    );
  }
}
