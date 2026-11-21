part of 'widgets.dart';

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
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

/// Высота шапки страницы: у всех вкладок заголовок стоит на одном и том же месте — вверху.
const double kHeaderHeight = 76;

/// Заголовок страницы: крупное название и маленькая подпись под ним.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.maxLines = 1});
  final String title;
  final String? subtitle;
  final int maxLines;

  /// Однострочный текст шапки при нехватке места уменьшается, а не обрезается.
  static Widget _shrink(Widget text) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: text);

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // Длинное название (например, предмета) занимает до двух строк и берёт шрифт помельче, поэтому читается целиком.
    final long = maxLines > 1 && title.length > 26;
    final style = (long ? tt.headlineSmall : tt.headlineMedium)?.copyWith(
      fontWeight: JournalType.heading,
      height: maxLines > 1 ? 1.1 : null,
    );
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          maxLines > 1
              ? Text(title, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style)
              : _shrink(Text(title, maxLines: 1, softWrap: false, style: style)),
          if (subtitle != null)
            _shrink(
              Text(
                subtitle!,
                maxLines: 1,
                softWrap: false,
                style: tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// Шапка вложенного экрана (настройки, предмет): та же высота, шрифт и положение названия, что и у вкладок,
/// слева кнопка «Назад».
class SubHeader extends StatelessWidget {
  const SubHeader(this.title, {super.key, this.subtitle, this.maxLines = 1});
  final String title;
  final String? subtitle;
  final int maxLines;

  @override
  Widget build(BuildContext context) => SliverAppBar(
    pinned: true,
    toolbarHeight: kHeaderHeight,
    titleSpacing: 0,
    backgroundColor: context.cs.surface,
    title: PageTitle(title, subtitle: subtitle, maxLines: maxLines),
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
          backgroundColor: cs.surface,
          title: PageTitle(title, subtitle: subtitle),
          actions: actions,
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: bottomGap)),
      ],
    );
    return ContentFrame(
      child: onRefresh == null ? view : RefreshIndicator(onRefresh: onRefresh!, child: view),
    );
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
  const SectionHeader(this.text, {super.key, this.trailing, this.top = 24, this.trailingColor, this.onTap});
  final String text;
  final String? trailing;
  final double top;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: context.tt.titleSmall?.copyWith(color: context.cs.primary, fontWeight: JournalType.emphasis),
    );
    final row = Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, top, 4, 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            label,
            if (trailing != null)
              Text(
                trailing!,
                style: context.tt.labelLarge?.copyWith(color: trailingColor ?? context.cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: row);
  }
}
