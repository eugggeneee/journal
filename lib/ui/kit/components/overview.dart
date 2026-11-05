import 'package:material_ui/material_ui.dart';

import '../../../core/haptics.dart';
import '../animation/motion.dart';
import '../animation/reveal.dart';
import '../foundation/ctx.dart';
import '../inputs/pickers.dart';
import 'widgets.dart';

// Общий «скелет» страниц «Оценки» и «Пропуски»: итоговая карточка, переключатель режимов,
// фильтр, карточки предметов и строки журнала. Страницы отличаются только данными и цветами.

/// Итоговая карточка страницы: цветная заливка, мягкие круги и плавное появление.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.tone, required this.child});
  final Tone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) => Appear(
        child: AnimatedContainer(
          duration: Motion.long,
          curve: Motion.standard,
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(32)),
          child: ArtCircles(
            color: tone.fg,
            radius: 32,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: child,
            ),
          ),
        ),
      );
}

/// Верх итоговой карточки: подпись, крупное число (с единицей) и короткие пояснения справа.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.caption,
    required this.value,
    required this.fg,
    this.unit,
    this.aside = const [],
  });
  final String caption;

  /// Крупное число — обычно [AnimatedNumber].
  final Widget value;
  final Color fg;
  final String? unit;

  /// Одна-две строки справа («12 оценок», «5 предметов»).
  final List<String> aside;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(caption, style: tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            value,
            if (unit != null) ...[
              const SizedBox(width: 8),
              Text(unit!, style: tt.titleMedium?.copyWith(color: fg)),
            ],
          ]),
        ]),
      ),
      if (aside.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < aside.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            Text(aside[i], style: tt.titleSmall?.copyWith(color: fg)),
          ],
        ]),
    ]);
  }
}

/// Цветная «таблетка» со значением (средний балл, часы). Цвет и цифры меняются плавно.
class ValuePill extends StatelessWidget {
  const ValuePill({super.key, required this.tone, required this.child});
  final Tone tone;

  /// Содержимое без собственного цвета (обычно [AnimatedNumber]) — цвет текста задаёт таблетка.
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.short,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(18)),
        child: AnimatedDefaultTextStyle(
          duration: Motion.short,
          curve: Motion.standard,
          style: (context.tt.titleMedium ?? const TextStyle()).copyWith(color: tone.fg, fontWeight: FontWeight.w800),
          child: child,
        ),
      );
}

/// Карточка предмета в обзоре: название, подпись, график снизу и значение справа.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.index,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.bottom,
    required this.trailing,
    this.onTap,
  });
  final int index;
  final int count;
  final String title;
  final String subtitle;
  final Widget bottom;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SegmentCard(
      index: index,
      count: count,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              bottom,
            ]),
          ),
          const SizedBox(width: 12),
          trailing,
        ]),
      ),
    );
  }
}

/// Строка журнала: значок слева, название и пояснение, справа короткая подпись (дата, часы).
/// Смахивание влево удаляет, вправо — своё действие (если задано).
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.index,
    required this.count,
    required this.badge,
    required this.title,
    required this.trailing,
    this.subtitle = '',
    this.onTap,
    this.dismissKey,
    this.onDelete,
    this.onSwipeRight,
    this.swipeRightIcon = Icons.check_rounded,
  });
  final int index;
  final int count;
  final Widget badge;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;
  final Key? dismissKey;
  final VoidCallback? onDelete;
  final VoidCallback? onSwipeRight;
  final IconData swipeRightIcon;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SegmentCard(
      index: index,
      count: count,
      dismissKey: dismissKey,
      onDelete: onDelete,
      onSwipeRight: onSwipeRight,
      swipeRightIcon: swipeRightIcon,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          badge,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (subtitle.isNotEmpty)
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: context.tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Переключатель «Предметы / Журнал» — одинаковый на страницах оценок и пропусков.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.menu_book_rounded), label: Text('Предметы')),
            ButtonSegment(value: 1, icon: Icon(Icons.history_rounded), label: Text('Журнал')),
          ],
          selected: {value},
          onSelectionChanged: (s) {
            Haptics.selection();
            onChanged(s.first);
          },
        ),
      );
}

/// Содержимое режима: при смене режима (новый [key]) плавно проявляется, а карточки внутри
/// въезжают каскадом.
class FadeInSlivers extends StatefulWidget {
  const FadeInSlivers({super.key, required this.slivers});
  final List<Widget> slivers;

  @override
  State<FadeInSlivers> createState() => _FadeInSliversState();
}

class _FadeInSliversState extends State<FadeInSlivers> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.medium);
  late final Animation<double> _fade = _c.drive(CurveTween(curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduce) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SliverFadeTransition(opacity: _fade, sliver: SliverMainAxisGroup(slivers: widget.slivers));
}

/// Кнопка-фильтр над списком журнала — на обеих страницах на одном и том же месте.
class SliverFilterRow extends StatelessWidget {
  const SliverFilterRow({super.key, required this.label, required this.active, required this.onTap, required this.onClear});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterButton(icon: Icons.filter_list_rounded, label: label, active: active, onClear: onClear, onTap: onTap),
          ),
        ),
      );
}

/// Короткое сообщение в списке («ничего не найдено»).
class SliverNote extends StatelessWidget {
  const SliverNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(text, textAlign: TextAlign.center, style: context.tt.bodyLarge?.copyWith(color: context.cs.onSurfaceVariant)),
          ),
        ),
      );
}
