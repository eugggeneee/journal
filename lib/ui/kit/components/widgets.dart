import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/haptics.dart';
import '../animation/motion.dart';
import '../animation/reveal.dart';
import '../foundation/ctx.dart';

/// Запас снизу под плавающую кнопку, чтобы она не закрывала последние элементы списка.
const double kFabClearance = 104;

/// Ограничивает ширину содержимого на планшетах и учитывает боковые вырезы экрана.
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = 840});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
        ),
      );
}

/// Высота шапки страницы: у всех вкладок заголовок стоит на одном и том же месте — вверху.
const double kHeaderHeight = 76;

/// Заголовок страницы: крупное название и маленькая подпись под ним.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
              ),
          ],
        ),
      );
}

/// Страница с закреплённой шапкой: название всегда в самом верху, при прокрутке шапка остаётся на месте.
class LargePage extends StatelessWidget {
  const LargePage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.onRefresh,
    this.bottomGap = kFabClearance,
  });
  final String title;
  final String? subtitle;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  /// Запас снизу: под плавающую кнопку нужен [kFabClearance], на страницах без кнопки достаточно небольшого.
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final view = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: kHeaderHeight,
          titleSpacing: 20,
          scrolledUnderElevation: 0,
          backgroundColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.scrolledUnder) ? cs.surfaceContainer : cs.surface,
          ),
          title: PageTitle(title, subtitle: subtitle),
          actions: actions,
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: bottomGap)),
      ],
    );
    return ContentFrame(child: onRefresh == null ? view : RefreshIndicator(onRefresh: onRefresh!, child: view));
  }
}

/// Горизонтальные поля списка.
class Inset extends StatelessWidget {
  const Inset({super.key, required this.children, this.top = 0});
  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: EdgeInsets.fromLTRB(16, top, 16, 0),
        sliver: SliverList.list(children: children),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing, this.top = 24});
  final String text;
  final String? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, top, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: context.tt.titleSmall?.copyWith(color: context.cs.primary, fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) Text(trailing!, style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

/// Иконка в «печенье» — фирменная выразительная форма Material 3 Expressive.
/// Цвета меняются плавно.
class CookieIcon extends StatelessWidget {
  const CookieIcon({super.key, required this.icon, this.size = 96, this.bg, this.fg});
  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final iconColor = fg ?? context.cs.onPrimaryContainer;
    return AnimatedContainer(
      duration: Motion.short,
      curve: Motion.standard,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: bg ?? context.cs.primaryContainer,
        shape: const StarBorder(points: 10, innerRadiusRatio: 0.86, pointRounding: 0.55, valleyRounding: 0.4),
      ),
      child: TweenAnimationBuilder<Color?>(
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
                  duration: context.motion(const Duration(milliseconds: 600)),
                  curve: Motion.spring,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: CookieIcon(icon: icon),
                ),
                const SizedBox(height: 24),
                Text(title, textAlign: TextAlign.center, style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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

/// Скруглённый значок с цифрой/текстом (номер пары, оценка). Цвет меняется плавно.
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
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(round ? size / 2 : size * 0.34),
        ),
        child: AnimatedDefaultTextStyle(
          duration: Motion.short,
          curve: Motion.standard,
          style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: tone.fg, height: 1),
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
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: onColorFor(accent), height: 1),
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
            if (icon != null) ...[Icon(icon, size: 14, color: tone.fg), const SizedBox(width: 4)],
            Text(text, style: context.tt.labelMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w700)),
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
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: track ?? context.cs.surfaceContainerHighest)),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: radius)),
            ),
          ),
        ]),
      ),
    );
  }
}

BorderRadius segmentRadius(int i, int n, {double outer = 28, double inner = 6}) => BorderRadius.vertical(
      top: Radius.circular(i == 0 ? outer : inner),
      bottom: Radius.circular(i == n - 1 ? outer : inner),
    );

/// Элемент «сегментированного списка» Material 3 Expressive: крайние карточки скруглены сильнее,
/// между карточками — тонкий зазор. Умеет смахиваться: влево — удалить, вправо — своё действие.
/// Значок под карточкой растёт вместе со смахиванием, а когда порог пройден, откликается вибрацией.
class SegmentCard extends StatefulWidget {
  const SegmentCard({
    super.key,
    required this.index,
    required this.count,
    required this.child,
    this.color,
    this.onTap,
    this.onLongPress,
    this.dismissKey,
    this.onDelete,
    this.onSwipeRight,
    this.swipeRightIcon = Icons.check_rounded,
  });
  final int index;
  final int count;
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Key? dismissKey;
  final VoidCallback? onDelete;
  final VoidCallback? onSwipeRight;
  final IconData swipeRightIcon;

  @override
  State<SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<SegmentCard> {
  /// Доля смахивания 0…1 (порог срабатывания у Dismissible — 0,4 ширины).
  final ValueNotifier<double> _swipe = ValueNotifier<double>(0);

  @override
  void dispose() {
    _swipe.dispose();
    super.dispose();
  }

  void _onUpdate(DismissUpdateDetails d) {
    if (d.reached && !d.previousReached) Haptics.selection();
    _swipe.value = d.progress;
  }

  Widget _swipeBackground({required Color bg, required Color fg, required IconData icon, required Alignment alignment}) => Container(
        color: bg,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ValueListenableBuilder<double>(
          valueListenable: _swipe,
          builder: (context, progress, child) {
            final t = (progress / 0.4).clamp(0.0, 1.0).toDouble();
            return Opacity(opacity: t, child: Transform.scale(scale: 0.6 + 0.4 * Motion.spring.transform(t), child: child));
          },
          child: Icon(icon, color: fg),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final r = segmentRadius(widget.index, widget.count);
    final d = context.motion(Motion.short);
    Widget body = Material(
      color: widget.color ?? cs.surfaceContainerLow,
      child: InkWell(onTap: widget.onTap, onLongPress: widget.onLongPress, child: widget.child),
    );
    if (widget.dismissKey != null) {
      body = Dismissible(
        key: widget.dismissKey!,
        direction: widget.onSwipeRight != null ? DismissDirection.horizontal : DismissDirection.endToStart,
        onUpdate: _onUpdate,
        background: _swipeBackground(
          bg: cs.primaryContainer,
          fg: cs.onPrimaryContainer,
          icon: widget.swipeRightIcon,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _swipeBackground(
          bg: cs.errorContainer,
          fg: cs.onErrorContainer,
          icon: Icons.delete_outline_rounded,
          alignment: Alignment.centerRight,
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            widget.onSwipeRight?.call();
            return false;
          }
          return true;
        },
        onDismissed: (_) => widget.onDelete?.call(),
        child: body,
      );
    }
    // Когда рядом появляется или исчезает карточка, скругления и зазоры меняются плавно.
    return Appear(
      index: widget.index,
      child: AnimatedPadding(
        duration: d,
        curve: Motion.standard,
        padding: EdgeInsets.only(bottom: widget.index == widget.count - 1 ? 0 : 2),
        child: PressScale(
          enabled: widget.onTap != null || widget.onLongPress != null,
          child: TweenAnimationBuilder<BorderRadius?>(
            tween: BorderRadiusTween(end: r),
            duration: d,
            curve: Motion.standard,
            builder: (context, radius, child) => ClipRRect(borderRadius: radius ?? r, child: child),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Украшение карточки: два мягких круга в углах, как на значке приложения.
class ArtCircles extends StatelessWidget {
  const ArtCircles({super.key, required this.color, required this.child, this.radius = 28});
  final Color color;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(children: [
          Positioned(top: -52, left: -40, child: _Disc(150, color.withValues(alpha: 0.16))),
          Positioned(top: -22, left: -12, child: _Disc(84, color.withValues(alpha: 0.12))),
          Positioned(bottom: -64, right: -48, child: _Disc(170, color.withValues(alpha: 0.14))),
          child,
        ]),
      );
}

class _Disc extends StatelessWidget {
  const _Disc(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)));
}
