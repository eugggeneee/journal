import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../data/store.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/edge_fade.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/selectors.dart';
import '../kit/inputs/settings_tiles.dart';
import '../profile/theme_widgets.dart';
import '../settings/bells_page.dart';
import '../settings/group_picker.dart';
import '../settings/settings_pages.dart';

/// Приветствие при первом запуске: знакомство → возможности → группа → стартовые настройки.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _count = 4;
  static const _groupPage = 2;

  PageController _pc = PageController();
  int _page = 0;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    // приветствие уже проходили, но группы нет (например, после восстановления копии) — сразу к выбору группы
    if (StoreScope.of(context).onboarded) {
      _page = _groupPage;
      _pc.dispose();
      _pc = PageController(initialPage: _groupPage);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int p) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (context.reduceMotion) {
      _pc.jumpToPage(p);
    } else {
      _pc.animateToPage(p, duration: const Duration(milliseconds: 380), curve: Motion.standard);
    }
  }

  void _next() {
    Haptics.selection();
    if (_page == _count - 1) {
      StoreScope.repoOf(context).prefetch(respectSetting: false);
      StoreScope.of(context).finishOnboarding();
    } else {
      _go(_page + 1);
    }
  }

  void _prev() {
    if (_page > 0) _go(_page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final canNext = _page != _groupPage || store.hasGroup;

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: IgnorePointer(child: _Backdrop())),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [
                  Expanded(
                    child: PageView(
                      controller: _pc,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [_welcome(context), _features(context), _group(context, store), _settings(context)],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _Dots(count: _count, index: _page),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canNext ? _next : null,
                          child: Swap(
                            alignment: Alignment.center,
                            child: Text(
                              _page == _count - 1 ? 'Начать' : 'Продолжить',
                              key: ValueKey(_page == _count - 1),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: Center(child: _page > 0 ? TextButton(onPressed: _prev, child: const Text('Назад')) : null),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ───────────── страницы ─────────────

  /// Прокручиваемая страница: нижний край плавно растворяется, а не обрезается резкой линией.
  Widget _scrolling(List<Widget> children, {double top = 24}) => EdgeFade(
        top: 16,
        bottom: 28,
        child: ListView(padding: EdgeInsets.fromLTRB(24, top, 24, 28), children: children),
      );

  Widget _title(BuildContext context, String title, String subtitle) => Column(children: [
        Text(title, textAlign: TextAlign.center, style: context.tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(subtitle, textAlign: TextAlign.center, style: context.tt.bodyLarge?.copyWith(height: 1.4, color: context.cs.onSurfaceVariant)),
      ]);

  Widget _welcome(BuildContext context) {
    final cs = context.cs;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.55, end: 1),
            duration: context.motion(const Duration(milliseconds: 1000)),
            curve: Curves.elasticOut,
            builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: v, child: child)),
            child: CookieIcon(icon: Icons.school_rounded, size: 156, bg: cs.primary, fg: cs.onPrimary),
          ),
          const SizedBox(height: 36),
          Text('Journal', textAlign: TextAlign.center, style: context.tt.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('МГТЭК · Дневник', textAlign: TextAlign.center, style: context.tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            'Расписание, оценки и пропуски — всё в одном месте.',
            textAlign: TextAlign.center,
            style: context.tt.titleMedium?.copyWith(height: 1.4, color: cs.onSurfaceVariant, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 28),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(child: Text('Данные хранятся только на вашем устройстве', style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
          ]),
        ]),
      ),
    );
  }

  Widget _features(BuildContext context) {
    final cs = context.cs;
    return _scrolling([
      _title(context, 'Всё под рукой', 'Три вещи, ради которых вы открываете дневник.'),
      const SizedBox(height: 28),
      _FeatureCard(
        index: 0,
        icon: Icons.calendar_month_rounded,
        bg: cs.primaryContainer,
        fg: cs.onPrimaryContainer,
        title: 'Расписание',
        text: 'Расписание вашей группы с сайта колледжа на любую дату. Уже загруженные дни доступны без интернета.',
      ),
      const SizedBox(height: 12),
      _FeatureCard(
        index: 1,
        icon: Icons.star_rounded,
        bg: cs.tertiaryContainer,
        fg: cs.onTertiaryContainer,
        title: 'Оценки',
        text: 'Записывайте оценки по 10-балльной шкале с пометками и следите за средним баллом по предметам.',
      ),
      const SizedBox(height: 12),
      _FeatureCard(
        index: 2,
        icon: Icons.event_busy_rounded,
        bg: cs.errorContainer,
        fg: cs.onErrorContainer,
        title: 'Пропуски',
        text: 'Отмечайте пропуски одним нажатием на пару — или сразу весь день — и смотрите, сколько часов набралось.',
      ),
    ]);
  }

  Widget _group(BuildContext context, AppStore store) {
    final cs = context.cs;
    final has = store.hasGroup;
    final group = store.settings.group;
    return _scrolling([
      _title(context, 'Ваша группа', 'Выберите группу из списка на сайте колледжа или введите её номер.'),
      const SizedBox(height: 32),
      Appear(
        child: PressScale(
          scale: 0.99,
          child: Material(
            color: has ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: ArtCircles(
              color: has ? cs.primary : cs.secondary,
              child: InkWell(
                onTap: () {
                  Haptics.selection();
                  showGroupSheet(
                    context,
                    selected: group,
                    onSelected: (g) {
                      Haptics.selection();
                      store.setGroup(g);
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    CookieIcon(
                      icon: Icons.groups_rounded,
                      size: 64,
                      bg: has ? cs.primary : cs.secondaryContainer,
                      fg: has ? cs.onPrimary : cs.onSecondaryContainer,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          has ? 'Группа $group' : 'Выбрать группу',
                          style: context.tt.headlineSmall?.copyWith(
                            color: has ? cs.onPrimaryContainer : cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          has ? 'Нажмите, чтобы сменить' : 'Нажмите, чтобы открыть список',
                          style: context.tt.bodyMedium?.copyWith(color: has ? cs.onPrimaryContainer.withValues(alpha: 0.85) : cs.onSurfaceVariant),
                        ),
                      ]),
                    ),
                    Icon(Icons.expand_less_rounded, color: has ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Appear(
        index: 2,
        child: PressScale(
          scale: 0.99,
          child: Material(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Haptics.selection();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BellsPage()));
              },
              child: BadgeRow(
                icon: Icons.notifications_active_rounded,
                tone: Tone(cs.tertiaryContainer, cs.onTertiaryContainer),
                title: 'Время пар',
                subtitle: store.settings.bells.values.any((p) => !p.isEmpty) ? bellsSummary(store.settings) : 'По желанию: введите звонки своей группы',
                trailing: store.settings.bells.values.any((p) => !p.isEmpty)
                    ? Icon(Icons.check_circle_rounded, color: cs.primary)
                    : Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        child: Text(
          'Это необязательно: время пар можно ввести позже в профиле.',
          textAlign: TextAlign.center,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    ]);
  }

  Widget _settings(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    return _scrolling(top: 12, [
      _title(context, 'Настройте под себя', 'Всё это можно изменить позже в профиле.'),
      const SectionHeader('Оформление', top: 18),
      const ThemeSelector(),
      const SizedBox(height: 10),
      const ThemeColorField(),
      const SectionHeader('Быстрый пропуск', top: 18),
      const HoursSelector(),
      const SectionHeader('Поведение', top: 18),
      SegmentCard(
        index: 0,
        count: 2,
        onTap: () => store.setHaptics(!s.haptics),
        child: SettingsTile(
          icon: Icons.vibration_rounded,
          title: 'Виброотклик',
          subtitle: 'Лёгкая вибрация при нажатиях и отметках',
          trailing: SettingsSwitch(value: s.haptics, onChanged: store.setHaptics),
        ),
      ),
      SegmentCard(
        index: 1,
        count: 2,
        onTap: () {
          Haptics.selection();
          store.setAutoRefresh(!s.autoRefresh);
        },
        child: SettingsTile(
          icon: Icons.sync_rounded,
          title: 'Автообновление',
          subtitle: 'Подгружать расписание при запуске',
          trailing: SettingsSwitch(value: s.autoRefresh, onChanged: store.setAutoRefresh),
        ),
      ),
    ]);
  }
}

// ───────────────────────── оформление ─────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Stack(children: [
      Positioned(top: -140, left: -100, child: _Orb(320, cs.primaryContainer.withValues(alpha: 0.9))),
      Positioned(top: 220, right: -160, child: _Orb(340, cs.tertiaryContainer.withValues(alpha: 0.8))),
      Positioned(bottom: -140, left: -80, child: _Orb(320, cs.secondaryContainer.withValues(alpha: 0.9))),
    ]);
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.index, required this.icon, required this.bg, required this.fg, required this.title, required this.text});
  final int index;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Appear(
        index: index + 1,
        child: Card(
          color: context.cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, size: 26, color: fg),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(text, style: context.tt.bodyMedium?.copyWith(height: 1.35, color: context.cs.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      label: 'Шаг ${index + 1} из $count',
      excludeSemantics: true,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: context.motion(Motion.short),
            curve: Motion.standard,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
      ]),
    );
  }
}
