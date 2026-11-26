part of 'widgets.dart';

/// Иконка в «печенье» — фирменная выразительная форма Material 3 Expressive.
/// Цвета меняются плавно.
class CookieIcon extends StatelessWidget {
  const CookieIcon({super.key, this.icon, this.glyph, this.size = 96, this.bg, this.fg})
    : assert(icon != null || glyph != null);

  /// Значок Material; вместо него можно передать готовое изображение в [glyph].
  final IconData? icon;
  final Widget? glyph;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final tone = iconTone(context.cs);
    final iconColor = fg ?? tone.fg;
    return AnimatedContainer(
      duration: Motion.short,
      curve: Motion.standard,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: bg ?? tone.bg,
        shape: const StarBorder(points: 10, innerRadiusRatio: 0.86, pointRounding: 0.55, valleyRounding: 0.4),
      ),
      child:
          glyph ??
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: iconColor),
            duration: Motion.short,
            curve: Motion.standard,
            builder: (context, color, _) => Icon(icon, size: size * 0.42, color: color ?? iconColor),
          ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Appear(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Значок «вырастает» с лёгкой пружинкой.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.7, end: 1),
              duration: Motion.ms(600),
              curve: Motion.spring,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: CookieIcon(icon: icon),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.tt.headlineSmall?.copyWith(fontWeight: JournalType.emphasis),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.tt.bodyLarge?.copyWith(color: context.cs.onSurfaceVariant, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    ),
  );
}

/// Скруглённый значок с цифрой/текстом (номер пары, отметка). Цвет меняется плавно.
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.text, {super.key, required this.tone, this.size = 48, this.round = true});
  final String text;
  final Tone tone;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.short,
    curve: Motion.standard,
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(round ? size / 2 : size * 0.34)),
    child: AnimatedDefaultTextStyle(
      duration: Motion.short,
      curve: Motion.standard,
      style: TextStyle(fontSize: size * 0.4, fontWeight: JournalType.heading, color: tone.fg, height: 1),
      child: Text(text),
    ),
  );
}

/// Маленькая плашка Material с числом часов пропуска. Садится на угол значка пары
/// и не меняет размеры карточки: красная — без уважительной причины, зелёная — по уважительной.
class AbsenceBadge extends StatelessWidget {
  const AbsenceBadge({super.key, required this.hours, required this.excused, required this.ringColor});
  final int hours;
  final bool excused;

  /// Цвет карточки под плашкой — по нему рисуется тонкий «вырез» вокруг плашки.
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final accent = absenceAccent(context, excused: excused);
    return Semantics(
      label: 'Пропуск: ${hoursText(hours)}${excused ? ', по уважительной причине' : ''}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ringColor, width: 2),
        ),
        child: Text(
          '$hours',
          style: TextStyle(fontSize: 11.5, fontWeight: JournalType.heading, color: onColorFor(accent), height: 1),
        ),
      ),
    );
  }
}

/// Пилюля с короткой подписью.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.tone, this.icon});
  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(100)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[IconBox(icon: icon!, size: 20, glyphSize: 14), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            text,
            style: context.tt.labelMedium?.copyWith(color: tone.fg, fontWeight: JournalType.emphasis),
          ),
        ),
      ],
    ),
  );
}

/// Полоса прогресса с закруглениями. Рисуется сама, поэтому выглядит одинаково на любой версии Flutter:
/// без «точки» на конце и без зазора между заливкой и дорожкой. [track] — цвет дорожки.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, required this.color, this.height = 10, this.track});
  final double value;
  final Color color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track ?? context.cs.surfaceContainerHighest)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0).toDouble(),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
