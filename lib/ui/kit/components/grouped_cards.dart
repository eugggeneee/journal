part of 'widgets.dart';

BorderRadius segmentRadius(
  int i,
  int n, {
  double outer = JournalLayout.cardRadius,
  double inner = JournalLayout.joinedRadius,
}) => BorderRadius.vertical(
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
    this.borderRadius,
    this.dismissKey,
    this.onDelete,
    this.onSwipeRight,
    this.swipeRightIcon = Icons.check_rounded,
    this.appear = true,
  });
  final int index;
  final int count;
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Key? dismissKey;
  final VoidCallback? onDelete;
  final VoidCallback? onSwipeRight;
  final IconData swipeRightIcon;

  /// Плавное появление при первом показе (выключается, когда карточку анимирует родитель).
  final bool appear;

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

  Widget _swipeBackground({
    required Color bg,
    required Color fg,
    required IconData icon,
    required Alignment alignment,
  }) => Container(
    color: bg,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: ValueListenableBuilder<double>(
      valueListenable: _swipe,
      builder: (context, progress, child) {
        final t = (progress / 0.4).clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.6 + 0.4 * Motion.spring.transform(t), child: child),
        );
      },
      child: Icon(icon, color: fg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final r = widget.borderRadius ?? segmentRadius(widget.index, widget.count);
    final d = context.motion(Motion.short);
    Widget inner = InkWell(onTap: widget.onTap, child: widget.child);
    final onLong = widget.onLongPress;
    if (onLong != null) {
      // Удержание срабатывает быстрее стандартных полусекунды: отметка пропуска не заставляет ждать.
      inner = RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: kQuickHold),
            (r) => r.onLongPress = () {
              Haptics.selection();
              onLong();
            },
          ),
        },
        child: inner,
      );
    }
    Widget body = Material(color: widget.color ?? cs.surfaceContainerLow, child: inner);
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
    final card = AnimatedPadding(
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
    );
    return widget.appear ? Appear(index: widget.index, child: card) : card;
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
    child: Stack(
      children: [
        Positioned(top: -52, left: -40, child: _Disc(150, color.withValues(alpha: 0.16))),
        Positioned(top: -22, left: -12, child: _Disc(84, color.withValues(alpha: 0.12))),
        Positioned(bottom: -64, right: -48, child: _Disc(170, color.withValues(alpha: 0.14))),
        child,
      ],
    ),
  );
}

class _Disc extends StatelessWidget {
  const _Disc(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// Значок в цветном квадрате: тот же размер и скругление, что у номеров пар и оценок. Основа строк списков.
class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, this.size = 44, this.glyphSize = 24});
  final IconData icon;
  final double glyphSize;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = iconTone(context.cs);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(size * 14 / 44)),
      child: Icon(icon, size: glyphSize, color: tone.fg),
    );
  }
}

/// Одна геометрия для равноправных действий и показателей внутри группы.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.index,
    required this.count,
    required this.color,
    required this.child,
    required this.onTap,
  });
  final int index, count;
  final Color color;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    clipBehavior: Clip.antiAlias,
    borderRadius: BorderRadius.horizontal(
      left: Radius.circular(index == 0 ? JournalLayout.panelRadius : JournalLayout.joinedRadius),
      right: Radius.circular(index == count - 1 ? JournalLayout.panelRadius : JournalLayout.joinedRadius),
    ),
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: JournalLayout.touchTarget),
        child: child,
      ),
    ),
  );
}

class JournalRow extends StatelessWidget {
  const JournalRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.compact = false,
    this.padding = JournalLayout.rowPadding,
  });
  final bool compact;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: (compact ? context.tt.titleSmall : context.tt.titleMedium)?.copyWith(
                    fontWeight: JournalType.emphasis,
                    height: 1.2,
                  ),
                ),
                if (subtitle?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: (compact ? context.tt.bodySmall : context.tt.bodyMedium)?.copyWith(
                        color: context.cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null || onTap != null) ...[
            const SizedBox(width: 8),
            trailing ?? Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(JournalLayout.panelRadius),
      onTap: () {
        Haptics.selection();
        onTap!();
      },
      child: row,
    );
  }
}
