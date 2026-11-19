import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../data/store.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/gesture_guide.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/selectors.dart';
import '../kit/inputs/settings_tiles.dart';
import '../settings/bells_page.dart';
import '../settings/group_picker.dart';
import '../settings/settings_pages.dart';
import '../settings/theme_widgets.dart';

/// Приветствие при первом запуске: знакомство → возможности → жесты → группа → стартовые настройки.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _count = 5;
  static const _groupPage = 3;

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
      _pc.animateToPage(p, duration: Motion.page, curve: Motion.emphasized);
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
                      children: [_welcome(context), _features(context), _gestures(context), _group(context, store), _settings(context)],
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

  /// Страница без прокрутки: всё содержимое видно сразу. Если на очень маленьком экране или при крупном шрифте оно не
  /// помещается, страница целиком чуть уменьшается, а не прокручивается.
  Widget _fit(List<Widget> children) => LayoutBuilder(
        builder: (context, box) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      );

  Widget _title(BuildContext context, String title, String subtitle) => Column(children: [
        Text(title, textAlign: TextAlign.center, style: context.tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(subtitle, textAlign: TextAlign.center, style: context.tt.bodyLarge?.copyWith(height: 1.4, color: context.cs.onSurfaceVariant)),
      ]);

  Widget _welcome(BuildContext context) {
    final cs = context.cs;
    return _fit([
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.55, end: 1),
            duration: Motion.ms(900),
            curve: Motion.spring,
            builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: v, child: child)),
            child: CookieIcon(size: 144, bg: cs.primary, glyph: _BellSwing(size: 78, color: cs.onPrimary)),
          ),
          const SizedBox(height: 32),
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
    ]);
  }

  Widget _features(BuildContext context) {
    final cs = context.cs;
    return _fit([
      _title(context, 'Всё под рукой', 'Три вещи, ради которых вы открываете дневник.'),
      const SizedBox(height: 24),
      _FeatureCard(
        index: 0,
        icon: Icons.calendar_month_rounded,
        bg: cs.primaryContainer,
        fg: cs.onPrimaryContainer,
        title: 'Расписание',
        text: 'Расписание группы на любую дату. Загруженные дни доступны без интернета.',
      ),
      const SizedBox(height: 12),
      _FeatureCard(
        index: 1,
        icon: Icons.star_rounded,
        bg: cs.tertiaryContainer,
        fg: cs.onTertiaryContainer,
        title: 'Оценки',
        text: 'Оценки по 10-балльной шкале и средний балл по каждому предмету.',
      ),
      const SizedBox(height: 12),
      _FeatureCard(
        index: 2,
        icon: Icons.event_busy_rounded,
        bg: cs.errorContainer,
        fg: cs.onErrorContainer,
        title: 'Пропуски',
        text: 'Пропуск одним нажатием на пару или сразу на весь день.',
      ),
    ]);
  }

  Widget _gestures(BuildContext context) => _fit([
        _title(context, 'Жесты', 'Несколько движений, которые экономят время.'),
        const SizedBox(height: 20),
        const GestureGuide(compact: true),
      ]);

  Widget _group(BuildContext context, AppStore store) {
    final cs = context.cs;
    final has = store.hasGroup;
    final group = store.settings.group;
    return _fit([
      _title(context, 'Ваша группа', 'Выберите группу из списка на сайте колледжа или введите её номер.'),
      const SizedBox(height: 28),
      Appear(
        child: PressScale(
          scale: 0.99,
          child: Material(
            color: has ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(JournalLayout.cardRadius),
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
            borderRadius: BorderRadius.circular(JournalLayout.cardRadius),
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
          'Это необязательно: время пар можно ввести позже в настройках.',
          textAlign: TextAlign.center,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    ]);
  }

  Widget _settings(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    return _fit([
      _title(context, 'Настройте под себя', 'Всё это можно изменить позже в настройках.'),
      const SizedBox(height: 20),
      const ThemeSelector(),
      const SizedBox(height: 10),
      const ThemeColorField(),
      const SizedBox(height: 14),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JournalLayout.cardRadius)),
          child: JournalRow(leading: IconBox(icon: icon, tone: Tone(bg, fg)), title: title, subtitle: text),
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

/// Колокольчик приветствия: после появления один раз «звонит» и затихает, по нажатию звонит снова.
class _BellSwing extends StatefulWidget {
  const _BellSwing({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  State<_BellSwing> createState() => _BellSwingState();
}

class _BellSwingState extends State<_BellSwing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.ms(1700));
  Timer? _start;

  @override
  void initState() {
    super.initState();
    if (!Motion.off) {
      _start = Timer(Motion.ms(650), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _ring() {
    Haptics.selection();
    if (!Motion.off) _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _ring,
        child: AnimatedBuilder(
          animation: _c,
          child: Image.asset(
            'assets/icons/bell.png',
            height: widget.size,
            color: widget.color,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
          builder: (context, child) {
            final t = _c.value;
            // Затухающее покачивание: амплитуда падает к нулю вместе с временем.
            final angle = 0.34 * math.sin(t * math.pi * 5) * math.pow(1 - t, 2).toDouble();
            return Transform.rotate(angle: angle, alignment: const Alignment(0, -0.75), child: child);
          },
        ),
      );
}
