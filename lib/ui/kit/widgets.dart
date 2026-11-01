import 'package:material_ui/material_ui.dart';

import 'ctx.dart';

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

/// Страница с большим сворачивающимся заголовком Material 3.
class LargePage extends StatelessWidget {
  const LargePage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.onRefresh,
  });
  final String title;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final view = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar.large(title: Text(title), actions: actions),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: kFabClearance)),
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(8, top, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: context.tt.titleSmall?.copyWith(color: context.cs.primary, fontWeight: FontWeight.w700)),
            ),
            if (trailing != null) Text(trailing!, style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant)),
          ],
        ),
      );
}

/// Иконка в «печенье» — фирменная выразительная форма Material 3 Expressive.
class CookieIcon extends StatelessWidget {
  const CookieIcon({super.key, required this.icon, this.size = 96, this.bg, this.fg});
  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: bg ?? context.cs.primaryContainer,
          shape: const StarBorder(points: 10, innerRadiusRatio: 0.86, pointRounding: 0.55, valleyRounding: 0.4),
        ),
        child: Icon(icon, size: size * 0.42, color: fg ?? context.cs.onPrimaryContainer),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CookieIcon(icon: icon),
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
      );
}

/// Скруглённый значок с цифрой/текстом (номер пары, оценка).
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.text, {super.key, required this.tone, this.size = 48, this.round = true});
  final String text;
  final Tone tone;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(round ? size / 2 : size * 0.34),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: tone.fg, height: 1),
        ),
      );
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

/// Полоса прогресса с закруглениями.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, required this.color, this.height = 10});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0).toDouble(),
          minHeight: height,
          color: color,
          backgroundColor: context.cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height),
        ),
      );
}

BorderRadius segmentRadius(int i, int n, {double outer = 28, double inner = 6}) => BorderRadius.vertical(
      top: Radius.circular(i == 0 ? outer : inner),
      bottom: Radius.circular(i == n - 1 ? outer : inner),
    );

/// Элемент «сегментированного списка» Material 3 Expressive: крайние карточки скруглены сильнее,
/// между карточками — тонкий зазор. Умеет смахиваться: влево — удалить, вправо — своё действие.
class SegmentCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = context.cs;
    final r = segmentRadius(index, count);
    Widget body = Material(
      color: color ?? cs.surfaceContainerLow,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
    );
    if (dismissKey != null) {
      body = Dismissible(
        key: dismissKey!,
        direction: onSwipeRight != null ? DismissDirection.horizontal : DismissDirection.endToStart,
        background: Container(
          color: cs.primaryContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: Icon(swipeRightIcon, color: cs.onPrimaryContainer),
        ),
        secondaryBackground: Container(
          color: cs.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            onSwipeRight?.call();
            return false;
          }
          return true;
        },
        onDismissed: (_) => onDelete?.call(),
        child: body,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : 2),
      child: ClipRRect(borderRadius: r, child: body),
    );
  }
}
