import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../kit/animation/motion.dart';
import '../kit/foundation/ctx.dart';

/// Верх главной: цветная поверхность во всю ширину с закруглением снизу. Шапка (приветствие, настройки)
/// стоит прямо на ней, поэтому экран читается как один цельный блок, а не набор карточек.
/// Цвет плавно перетекает вместе с состоянием дня.
class HeroSurface extends StatelessWidget {
  const HeroSurface({super.key, required this.tone, required this.child, this.header});
  final Tone tone;
  final Widget child;

  /// Шапка на поверхности; получает цвет текста, подходящий к фону.
  final Widget Function(Color fg)? header;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final dark = ThemeData.estimateBrightnessForColor(tone.bg) == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: AnimatedContainer(
        duration: context.motion(Motion.long),
        curve: Motion.standard,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, top + 8, 20, 20),
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
      ),
    );
  }
}
