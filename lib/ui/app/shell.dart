import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../absences/absence_sheet.dart';
import '../absences/absences_page.dart';
import '../grades/grade_sheet.dart';
import '../grades/grades_page.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/tab_switcher.dart';
import '../kit/foundation/ctx.dart';
import '../profile/profile_page.dart';
import '../schedule/marks.dart';
import '../schedule/schedule_page.dart';
import 'scope.dart';

/// Оболочка: нижняя панель навигации на телефоне, боковая NavigationRail на планшете и ПК.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  static const _wide = 640.0;

  static const _items = [
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Расписание'),
    (Icons.star_outline_rounded, Icons.star_rounded, 'Оценки'),
    (Icons.event_busy_outlined, Icons.event_busy_rounded, 'Пропуски'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  int _tab = 0;
  bool _prefetched = false;

  // Кнопка «Добавить» на расписании раскрывается в три действия над затемнённым экраном.
  late final AnimationController _dial = AnimationController(vsync: this, duration: Motion.medium, reverseDuration: Motion.short);
  bool _dialOpen = false;

  final ScheduleController _sched = ScheduleController();
  late final List<Widget> _pages = [
    SchedulePage(controller: _sched),
    const GradesPage(),
    const AbsencesPage(),
    const ProfilePage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefetched) {
      _prefetched = true;
      StoreScope.repoOf(context).prefetch();
    }
  }

  @override
  void dispose() {
    _dial.dispose();
    _sched.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    Haptics.selection();
    if (_dialOpen) _setDial(false);
    setState(() => _tab = i);
  }

  void _setDial(bool open) {
    if (_dialOpen == open) return;
    setState(() => _dialOpen = open);
    if (context.reduceMotion) {
      _dial.value = open ? 1 : 0;
    } else if (open) {
      _dial.forward();
    } else {
      _dial.reverse();
    }
  }

  /// Закрывает меню и сразу открывает выбранное действие над расписанием выбранной даты.
  void _addAction(void Function(BuildContext host, DateTime date) action) {
    Haptics.selection();
    final date = _sched.selected;
    _setDial(false);
    action(context, date);
  }

  Widget _dialItem(int i, IconData icon, String label, Tone tone, VoidCallback onTap) {
    // Ближайшее к кнопке действие появляется первым.
    final start = (2 - i) * 0.12;
    final fade = _dial.drive(CurveTween(curve: Interval(start, start + 0.5, curve: Curves.easeOut)));
    final pop = _dial.drive(CurveTween(curve: Interval(start, start + 0.7, curve: Motion.spring)));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: pop.drive(Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)),
        child: ScaleTransition(
          scale: pop.drive(Tween<double>(begin: 0.8, end: 1)),
          alignment: Alignment.centerRight,
          child: Material(
            color: tone.bg,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: tone.fg),
                    const SizedBox(width: 12),
                    Text(label, style: context.tt.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Затемнение и три действия над кнопкой «Добавить».
  Widget _dialLayer() {
    final cs = context.cs;
    final grade = gradeTone(context, 9);
    final absence = absenceTone(context, excused: false);
    final mark = markTone(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_dialOpen,
        child: Stack(children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _dial,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setDial(false),
                child: ColoredBox(color: cs.scrim.withValues(alpha: 0.32)),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16 + 56 + 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              _dialItem(0, Icons.bookmark_rounded, 'Пометка', mark, () => _addAction((h, d) => showMarkSheet(h, d))),
              const SizedBox(height: 10),
              _dialItem(1, Icons.event_busy_rounded, 'Пропуск', absence, () => _addAction((h, d) => showAbsenceSheet(h, date: d))),
              const SizedBox(height: 10),
              _dialItem(2, Icons.star_rounded, 'Оценка', grade, () => _addAction((h, d) => showGradeSheet(h, date: d))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _fab(BuildContext context) {
    switch (_tab) {
      case 0:
        return FloatingActionButton.extended(
          key: const ValueKey('fab-add'),
          heroTag: null,
          onPressed: () {
            Haptics.selection();
            _setDial(!_dialOpen);
          },
          icon: AnimatedRotation(
            turns: _dialOpen ? 0.125 : 0,
            duration: context.motion(Motion.medium),
            curve: Motion.emphasized,
            child: const Icon(Icons.add_rounded),
          ),
          label: const Text('Добавить'),
        );
      case 1:
        return FloatingActionButton.extended(
          key: const ValueKey('fab-grade'),
          heroTag: null,
          onPressed: () {
            Haptics.selection();
            showGradeSheet(context);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Оценка'),
        );
      case 2:
        return FloatingActionButton.extended(
          key: const ValueKey('fab-absence'),
          heroTag: null,
          onPressed: () {
            Haptics.selection();
            showAbsenceSheet(context);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Пропуск'),
        );
      default:
        return const SizedBox.shrink(key: ValueKey('fab-none'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final tabs = TabSwitcher(index: _tab, children: _pages);
    final body = Stack(fit: StackFit.expand, children: [tabs, if (_tab == 0) _dialLayer()]);

    return PopScope(
      canPop: _tab == 0 && !_dialOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dialOpen) {
          _setDial(false);
        } else {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        body: wide
            ? Row(children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final it in _items)
                        NavigationRailDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: Text(it.$3)),
                    ],
                  ),
                ),
                Expanded(child: body),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _select,
                destinations: [
                  for (final it in _items) NavigationDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: it.$3),
                ],
              ),
        floatingActionButton: AnimatedSwitcher(
          duration: context.motion(Motion.short),
          switchInCurve: Motion.spring,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: _fab(context),
        ),
      ),
    );
  }
}
